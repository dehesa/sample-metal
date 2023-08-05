import Foundation
import Metal
import MetalKit

@MainActor final class TessellationRenderer: NSObject, MTKViewDelegate {
  /// The type of tessellation patch being rendered.
  var patchType: MTLPatchType = .triangle
  /// Indicates whether only the wireframe or the whole patch will be displayed.
  var wireframe: Bool = true
  /// Tessellation factors to be applied on the following renders.
  var factors: (edge: Float, inside: Float) = (2, 2)

  let device: MTLDevice
  private let queue: MTLCommandQueue
  private let library: MTLLibrary
  /// Compute pipelines for tessellation triangles and quads.
  private let computePipelines: (triangle: MTLComputePipelineState, quad: MTLComputePipelineState)
  /// Render pipelines for this project.
  private var renderPipelines: (triangle: MTLRenderPipelineState, quad: MTLRenderPipelineState)?
  /// Buffer needed to feed the compute/render pipelines.
  private let buffers: (tessellationFactors: MTLBuffer, triangleControlPoints: MTLBuffer, quadControlPoints: MTLBuffer)

  /// Designated initializer requiring passing the MetalKit view that will be driven by this pipeline.
  /// - parameter view: MetalKit view driven by the created pipeline.
  override init() {
    self.device = MTLCreateSystemDefaultDevice()!
    self.queue = device.makeCommandQueue()!
    self.library = device.makeDefaultLibrary()!

    let triangleFunction = self.library.makeFunction(name: "kernel_triangle")!
    let quadFunction = library.makeFunction(name: "kernel_quad")!
    self.computePipelines.triangle = try! self.device.makeComputePipelineState(function: triangleFunction)
    self.computePipelines.quad = try! self.device.makeComputePipelineState(function: quadFunction)

    self.buffers = Self.makeBuffers(device: self.device)
    super.init()
  }

  nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    MainActor.assumeIsolated {
      guard case .none = self.renderPipelines else { return }
      self.renderPipelines = Self.makeRenderPipelines(device: self.device, library: self.library, view: view)
    }
  }

  nonisolated func draw(in view: MTKView) {
    MainActor.assumeIsolated {
      autoreleasepool {
        guard let renderPipelines,
              let buffer = self.queue.makeCommandBuffer() else { return }
        buffer.label = "Tessellation Pass"

        if self.computeTessellationFactors(on: buffer),
           self.tessellateAndRender(view: view, on: buffer, renderPipelines: renderPipelines),
           let drawable = view.currentDrawable {
          buffer.present(drawable)
        }
        buffer.commit()
      }
    }
  }
}

private extension TessellationRenderer {
  static func makeRenderPipelines(device: MTLDevice, library: MTLLibrary, view: MTKView) -> (triangle: MTLRenderPipelineState, quad: MTLRenderPipelineState) {
    let pipelineDescriptor = MTLRenderPipelineDescriptor().configure { (pipeline) in
      // Vertex descriptor for the control point data.
      // This describes the inputs to the post-tessellation vertex function, delcared with the `stage_in` qualifier.
      pipeline.vertexDescriptor = MTLVertexDescriptor().configure { (vertex) in
        vertex.attributes[0].configure {
          $0.format = .float4
          $0.offset = 0
          $0.bufferIndex = 0
        }

        vertex.layouts[0].configure {
          $0.stepFunction = .perPatchControlPoint
          $0.stepRate = 1
          $0.stride = 4 * MemoryLayout<Float>.size
        }
      }
      // Configure common render properties
      pipeline.rasterSampleCount = view.sampleCount
      pipeline.colorAttachments[0].pixelFormat = view.colorPixelFormat
      pipeline.fragmentFunction = library.makeFunction(name: "fragment_both")!
      // Configure common tessellation properties
      pipeline.isTessellationFactorScaleEnabled = false
      pipeline.tessellationFactorFormat = .half
      pipeline.tessellationControlPointIndexType = .none
      pipeline.tessellationFactorStepFunction = .constant
      pipeline.tessellationOutputWindingOrder = .clockwise
      pipeline.tessellationPartitionMode = .fractionalEven
      pipeline.maxTessellationFactor = MetalView.maxTessellationFactor
    }

    pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_triangle")!
    let trianglePipeline = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

    pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_quad")!
    let quadPipeline = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

    return (trianglePipeline, quadPipeline)
  }

  static func makeBuffers(device: MTLDevice) -> (tessellationFactors: MTLBuffer, triangleControlPoints: MTLBuffer, quadControlPoints: MTLBuffer) {
    let triangleControlPointPositions: [Float] = [
      -0.8, -0.8, 0.0, 1.0,   // lower-left
       0.0,  0.8, 0.0, 1.0,   // upper-middle
       0.8, -0.8, 0.0, 1.0,   // lower-right
    ]

    let quadControlPointPositions: [Float] = [
      -0.8,  0.8, 0.0, 1.0,   // upper-left
       0.8,  0.8, 0.0, 1.0,   // upper-right
       0.8, -0.8, 0.0, 1.0,   // lower-right
       -0.8, -0.8, 0.0, 1.0,   // lower-left
    ]

    let triangleControlPointLength = triangleControlPointPositions.count * MemoryLayout<Float>.size
    let quadControlPointLength = quadControlPointPositions.count * MemoryLayout<Float>.size

    // Allocate memory for the tessellation factors, triangle control points, and quad control points.
    guard let factorsBuffer  = device.makeBuffer(length: 256, options: .storageModePrivate),
          let triangleBuffer = device.makeBuffer(bytes: triangleControlPointPositions, length: triangleControlPointLength, options: .storageModeShared),
          let quadBuffer     = device.makeBuffer(bytes: quadControlPointPositions, length: quadControlPointLength, options: .storageModeShared) else {
      fatalError("The Metal buffers couldn't be created.")
    }
    // More sophisticated tessellation passes might have additional buffers for per-patch user data.
    return (factorsBuffer.configure { $0.label = "Tessellation Factors" },
            triangleBuffer.configure { $0.label = "Control Points Triangle" },
            quadBuffer.configure { $0.label = "Control Points Quad" })
  }

  func computeTessellationFactors(on commandBuffer: MTLCommandBuffer) -> Bool {
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return false }
    encoder.label = "Compute Command Encoder"
    encoder.pushDebugGroup("Compute Tessellation Factors")
    // Set the correct pipeline.
    encoder.setComputePipelineState((self.patchType == .triangle) ? self.computePipelines.triangle : self.computePipelines.quad)
    // Bind the buffers (user selection & tessellation factor)
    encoder.setBytes(&factors.edge,   length: MemoryLayout.size(ofValue: factors.edge),   index: 0)
    encoder.setBytes(&factors.inside, length: MemoryLayout.size(ofValue: factors.inside), index: 1)
    encoder.setBuffer(self.buffers.tessellationFactors, offset: 0, index: 2)
    // Dispatch threadgroups
    encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))

    encoder.popDebugGroup()
    encoder.endEncoding()
    return true
  }

  func tessellateAndRender(view: MTKView, on commandBuffer: MTLCommandBuffer, renderPipelines: (triangle: MTLRenderPipelineState, quad: MTLRenderPipelineState)) -> Bool {
    guard let renderPassDescriptor = view.currentRenderPassDescriptor,
          let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return false }
    encoder.label = "Render Command Encoder"
    encoder.pushDebugGroup("Tessellate and Render")
    let numControlPoints: Int
    // Set the correct render pipeline and bind the correct control points buffer.
    if case .triangle = self.patchType {
      numControlPoints = 3
      encoder.setRenderPipelineState(renderPipelines.triangle)
      encoder.setVertexBuffer(self.buffers.triangleControlPoints, offset: 0, index: 0)
    } else {
      numControlPoints = 4
      encoder.setRenderPipelineState(renderPipelines.quad)
      encoder.setVertexBuffer(self.buffers.quadControlPoints, offset: 0, index: 0)
    }
    // Enable/Disable wireframe mode.
    encoder.setTriangleFillMode((self.wireframe) ? .lines : .fill)
    // Encode tessellation-specific commands.
    encoder.setTessellationFactorBuffer(self.buffers.tessellationFactors, offset: 0, instanceStride: 0)
    encoder.drawPatches(numberOfPatchControlPoints: numControlPoints, patchStart: 0, patchCount: 1, patchIndexBuffer: nil, patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)

    encoder.popDebugGroup()
    encoder.endEncoding()
    return true
  }
}
