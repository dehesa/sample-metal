import Foundation
import Metal
import MetalKit

final class TessellationPipeline: NSObject, MTKViewDelegate {
  /// The type of tessellation patch being rendered.
  var patchType: MTLPatchType = .triangle
  /// Indicates whether only the wireframe or the whole patch will be displayed.
  var wireframe: Bool = true
  /// Tessellation factors to be applied on the following renders.
  var factors: (edge: Float, inside: Float) = (2, 2)

  /// Basic Metal entities to interface with the assignated GPU.
  private let _metal: (device: MTLDevice, queue: MTLCommandQueue, library: MTLLibrary)
  /// Compute pipelines for tessellation triangles and quads.
  private let _computePipelines: (triangle: MTLComputePipelineState, quad: MTLComputePipelineState)
  /// Render pipelines for this project.
  private let _renderPipelines: (triangle: MTLRenderPipelineState, quad: MTLRenderPipelineState)
  /// Buffer needed to feed the compute/render pipelines.
  private let _buffers: (tessellationFactors: MTLBuffer, triangleControlPoints: MTLBuffer, quadControlPoints: MTLBuffer)

  /// Designated initializer requiring passing the MetalKit view that will be driven by this pipeline.
  /// - parameter view: MetalKit view driven by the created pipeline.
  init(view: MTKView) {
    self._metal = TessellationPipeline._setupMetal()
    self._computePipelines = TessellationPipeline._setupComputePipelines(device: _metal.device, library: _metal.library)
    self._renderPipelines = TessellationPipeline._setupRenderPipelines(device: _metal.device, library: _metal.library, view: view)
    self._buffers = TessellationPipeline._setupBuffers(device: _metal.device)

    super.init()

    view.device = self._metal.device
    view.delegate = self
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    autoreleasepool {
      guard let buffer = self._metal.queue.makeCommandBuffer() else { return }
      buffer.label = "Tessellation Pass"

      if self._computeTessellationFactors(on: buffer),
         self._tessellateAndRender(view: view, on: buffer),
         let drawable = view.currentDrawable {
        buffer.present(drawable)
      }
      buffer.commit()
    }
  }
}

private extension TessellationPipeline {
  /// Creates the basic *non-trasient* Metal objects needed for this project.
  /// - returns: A metal device, a metal command queue, and the default library (hopefully hosting the tessellation compute and vertex/fragment functions).
  static func _setupMetal() -> (device: MTLDevice, queue: MTLCommandQueue, library: MTLLibrary) {
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("Metal is not supported on this device.")
    }

    guard device.supportsFeatureSet(_minTessellationFeatureSet) else {
      fatalError("Tessellation is not supported on this device.")
    }

    guard let queue = device.makeCommandQueue() else {
      fatalError("A Metal command queue couldn't be created.")
    }

    guard let library = device.makeDefaultLibrary() else {
      fatalError("The default Metal library couldn't be found or couldn't be created.")
    }

    return (device, queue, library)
  }

  /// Creates the two compute pipelines (one for triangles, one for quads).
  /// - parameter device: Metal device needed to create pipeline state objects.
  /// - parameter library: Compile Metal code hosting the kernel functions driving the compute pipelines.
  static func _setupComputePipelines(device: MTLDevice, library: MTLLibrary) -> (triangle: MTLComputePipelineState, quad: MTLComputePipelineState) {
    guard let triangleFunction = library.makeFunction(name: "kernel_triangle"),
          let quadFunction = library.makeFunction(name: "kernel_quad") else {
      fatalError("The kernel functions calculating the tessellation factors couldn't be found/created.")
    }

    guard let trianglePipeline = try? device.makeComputePipelineState(function: triangleFunction),
          let quadPipeline = try? device.makeComputePipelineState(function: quadFunction) else {
      fatalError("The compute pipelines couldn't be created.")
    }

    return (trianglePipeline, quadPipeline)
  }

  static func _setupRenderPipelines(device: MTLDevice, library: MTLLibrary, view: MTKView) -> (triangle: MTLRenderPipelineState, quad: MTLRenderPipelineState) {
    guard let triangleFunction = library.makeFunction(name: "vertex_triangle"),
          let quadFunction = library.makeFunction(name: "vertex_quad"),
          let fragmentFunction = library.makeFunction(name: "fragment_both") else {
      fatalError("The render functions couldn't be found/created.")
    }

    let pipelineDescriptor = MTLRenderPipelineDescriptor().set { (pipeline) in
      // Vertex descriptor for the control point data.
      // This describes the inputs to the post-tessellation vertex function, delcared with the `stage_in` qualifier.
      pipeline.vertexDescriptor = MTLVertexDescriptor().set { (vertex) in
        vertex.attributes[0].setUp {
          $0.format = .float4
          $0.offset = 0
          $0.bufferIndex = 0
        }

        vertex.layouts[0].setUp {
          $0.stepFunction = .perPatchControlPoint
          $0.stepRate = 1
          $0.stride = 4 * MemoryLayout<Float>.size
        }
      }
      // Configure common render properties
      pipeline.sampleCount = view.sampleCount
      pipeline.colorAttachments[0].pixelFormat = view.colorPixelFormat
      pipeline.fragmentFunction = fragmentFunction
      // Configure common tessellation properties
      pipeline.isTessellationFactorScaleEnabled = false
      pipeline.tessellationFactorFormat = .half
      pipeline.tessellationControlPointIndexType = .none
      pipeline.tessellationFactorStepFunction = .constant
      pipeline.tessellationOutputWindingOrder = .clockwise
      pipeline.tessellationPartitionMode = .fractionalEven
      pipeline.maxTessellationFactor = _maxTessellationFactor
    }

    guard let pipelines: [MTLRenderPipelineState] = try? [triangleFunction, quadFunction].map({
      pipelineDescriptor.vertexFunction = $0
      return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }) else {
      fatalError("The post-tessellation vertex pipelines couldn't be created.")
    }

    return (pipelines[0], pipelines[1])
  }

  static func _setupBuffers(device: MTLDevice) -> (tessellationFactors: MTLBuffer, triangleControlPoints: MTLBuffer, quadControlPoints: MTLBuffer) {
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
          let triangleBuffer = device.makeBuffer(bytes: triangleControlPointPositions, length: triangleControlPointLength, options: _bufferStorageMode),
          let quadBuffer     = device.makeBuffer(bytes: quadControlPointPositions, length: quadControlPointLength, options: _bufferStorageMode) else {
      fatalError("The Metal buffers couldn't be created.")
    }
    // More sophisticated tessellation passes might have additional buffers for per-patch user data.
    return (factorsBuffer.set { $0.label = "Tessellation Factors" },
            triangleBuffer.set { $0.label = "Control Points Triangle" },
            quadBuffer.set { $0.label = "Control Points Quad" })
  }

  /// The minimum OSes supporting Tessellation.
  static var _minTessellationFeatureSet: MTLFeatureSet {
    #if os(macOS)
    .macOS_GPUFamily1_v2
    #elseif os(iOS)
    .iOS_GPUFamily3_v2
    #endif
  }

  /// The maximum Tessellation factor for the given OS.
  static var _maxTessellationFactor: Int {
    #if os(macOS)
    64
    #elseif os(iOS)
    16
    #endif
  }

  // OS Buffer storage mode
  static var _bufferStorageMode: MTLResourceOptions {
    #if arch(arm64)
    .storageModeShared
    #else
    .storageModeManaged
    #endif
  }

  func _computeTessellationFactors(on commandBuffer: MTLCommandBuffer) -> Bool {
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return false }
    encoder.label = "Compute Command Encoder"
    encoder.pushDebugGroup("Compute Tessellation Factors")
    // Set the correct pipeline.
    encoder.setComputePipelineState((self.patchType == .triangle) ? self._computePipelines.triangle : self._computePipelines.quad)
    // Bind the buffers (user selection & tessellation factor)
    encoder.setBytes(&factors.edge,   length: MemoryLayout.size(ofValue: factors.edge),   index: 0)
    encoder.setBytes(&factors.inside, length: MemoryLayout.size(ofValue: factors.inside), index: 1)
    encoder.setBuffer(self._buffers.tessellationFactors, offset: 0, index: 2)
    // Dispatch threadgroups
    encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))

    encoder.popDebugGroup()
    encoder.endEncoding()
    return true
  }

  func _tessellateAndRender(view: MTKView, on commandBuffer: MTLCommandBuffer) -> Bool {
    guard let renderPassDescriptor = view.currentRenderPassDescriptor,
          let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return false }
    encoder.label = "Render Command Encoder"
    encoder.pushDebugGroup("Tessellate and Render")
    let numControlPoints: Int
    // Set the correct render pipeline and bind the correct control points buffer.
    if case .triangle = self.patchType {
      numControlPoints = 3
      encoder.setRenderPipelineState(self._renderPipelines.triangle)
      encoder.setVertexBuffer(self._buffers.triangleControlPoints, offset: 0, index: 0)
    } else {
      numControlPoints = 4
      encoder.setRenderPipelineState(self._renderPipelines.quad)
      encoder.setVertexBuffer(self._buffers.quadControlPoints, offset: 0, index: 0)
    }
    // Enable/Disable wireframe mode.
    encoder.setTriangleFillMode((self.wireframe) ? .lines : .fill)
    // Encode tessellation-specific commands.
    encoder.setTessellationFactorBuffer(self._buffers.tessellationFactors, offset: 0, instanceStride: 0)
    encoder.drawPatches(numberOfPatchControlPoints: numControlPoints, patchStart: 0, patchCount: 1, patchIndexBuffer: nil, patchIndexBufferOffset: 0, instanceCount: 1, baseInstance: 0)

    encoder.popDebugGroup()
    encoder.endEncoding()
    return true
  }
}
