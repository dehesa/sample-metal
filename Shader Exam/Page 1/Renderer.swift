import Foundation
import MetalKit
import simd

@MainActor final class PikachuRenderer: NSObject, MTKViewDelegate {
  let device: MTLDevice
  private(set) var exercise: Exercise

  private let queue: MTLCommandQueue
  private let library: MTLLibrary
  private let pikachuMesh: MTKMesh
  private let pikacheTexture: MTLTexture
  private let firstPassPipeline: MTLRenderPipelineState
  private let depthPipeline: MTLDepthStencilState
  private var secondPassDescriptor: MTLRenderPipelineDescriptor
  private var secondPassPipeline: MTLRenderPipelineState
  private var depthTexture: MTLTexture?
  private var colorTexture: MTLTexture?

  init(device: MTLDevice, exercise: Exercise) {
    self.device = device
    self.exercise = exercise
    self.queue = device.makeCommandQueue()!
    // Define how pikachu's vertices are laid out.
    let modelIOVertices = MDLVertexDescriptor().configure {
      $0.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
      $0.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: 12, bufferIndex: 0)
      $0.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: 24, bufferIndex: 0)
      $0.layouts[0] = MDLVertexBufferLayout(stride: 32)
    }
    let pikachuVertices = MTKMetalVertexDescriptorFromModelIO(modelIOVertices)!
    // Instantiate the pikachu model with Model IO.
    let pikachuModelURL = Bundle.main.url(forResource: "pikachu", withExtension: "obj")!
    let pikachuAsset = MDLAsset(url: pikachuModelURL, vertexDescriptor: modelIOVertices, bufferAllocator: MTKMeshBufferAllocator(device: device))
    let modelIOMesh = pikachuAsset.childObjects(of: MDLMesh.self).first as! MDLMesh
    self.pikachuMesh = try! MTKMesh(mesh: modelIOMesh, device: device)
    // Load pikachu's texture
    let pikachuTextureURL = Bundle.main.url(forResource: "pikachu", withExtension: "png")!
    self.pikacheTexture = try! MTKTextureLoader(device: device).newTexture(URL: pikachuTextureURL, options: [.SRGB: false, .origin: MTKTextureLoader.Origin.flippedVertically]).configure {
      $0.label = .identifier(Self.id, "texture")
    }

    self.library = device.makeDefaultLibrary()!
    // First render pass (projecting pikachu's model into a flat texture).
    let firstPass = MTLRenderPipelineDescriptor().configure { [library] pipeline in
      pipeline.label = .identifier(Self.id, "pipeline", "first")
      pipeline.vertexFunction = library.makeFunction(name: "firstPassVertex")!
      pipeline.vertexDescriptor = pikachuVertices
      pipeline.fragmentFunction = library.makeFunction(name: "firstPassFragment")!
      pipeline.colorAttachments[0].pixelFormat = .rgba8Unorm
      pipeline.depthAttachmentPixelFormat = .depth32Float
    }
    self.firstPassPipeline = try! device.makeRenderPipelineState(descriptor: firstPass)
    // Second render pass (passing the previously generated texture and performing changes on it).
    self.secondPassDescriptor = MTLRenderPipelineDescriptor().configure { [library] pipeline in
      pipeline.label = .identifier(Self.id, "pipeline", "second")
      pipeline.vertexFunction = library.makeFunction(name: "secondPassVertex")
      pipeline.vertexDescriptor = MTLVertexDescriptor().configure {
        $0.attributes[0].configure { attribute in
          attribute.format = .float2
          attribute.offset = 0
          attribute.bufferIndex = 0
        }
        $0.attributes[1].configure { attribute in
          attribute.format = .float2
          attribute.offset = 8
          attribute.bufferIndex = 0
        }
        $0.layouts[0].stride = 16
      }
      pipeline.fragmentFunction = library.makeFunction(name: exercise.shaderFunctionName)
      pipeline.colorAttachments[0].pixelFormat = .rgba8Unorm
    }
    self.secondPassPipeline = try! device.makeRenderPipelineState(descriptor: self.secondPassDescriptor)
    // The 1st pass will use depth checks.
    let depthDescriptor = MTLDepthStencilDescriptor().configure {
      $0.label = .identifier(Self.id, "pipeline", "depth")
      $0.depthCompareFunction = .less
      $0.isDepthWriteEnabled = true
    }
    self.depthPipeline = device.makeDepthStencilState(descriptor: depthDescriptor)!
  }

  nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    // The color and depth textures need to match the framebuffer's size
    // Re-make them if the view size changes.
    MainActor.assumeIsolated {
      let (width, height) = (Int(size.width), Int(size.height))
      guard width > .zero, height > .zero else {
        self.colorTexture = .none
        self.depthTexture = .none
        return
      }

      let isDifferent = self.depthTexture.map { $0.width != width || $0.height != height } ?? true
      guard isDifferent else { return }

      let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false).configure {
        $0.storageMode = .shared
        $0.usage = [.shaderRead, .renderTarget]
      }
      self.colorTexture = self.device.makeTexture(descriptor: colorDescriptor)!.configure {
        $0.label = .identifier(Self.id, "texture", "color")
      }

      let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false).configure {
        $0.storageMode = .private
        $0.usage = .renderTarget
      }
      self.depthTexture = self.device.makeTexture(descriptor: depthDescriptor)!.configure {
        $0.label = .identifier(Self.id, "texture", "depth")
      }
    }
  }

  nonisolated func draw(in view: MTKView) {
    MainActor.assumeIsolated {
      guard let colorTexture, let depthTexture,
            let commandBuffer = self.queue.makeCommandBuffer(),
            let viewRenderDescriptor = view.currentRenderPassDescriptor else { return }

      let firstPass = MTLRenderPassDescriptor().configure {
        $0.colorAttachments[0].configure { attachment in
          attachment.texture = colorTexture
          attachment.clearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
          attachment.loadAction = .clear
          attachment.storeAction = .store
        }
        $0.depthAttachment.configure { attachment in
          attachment.texture = depthTexture
          attachment.clearDepth = 1
          attachment.loadAction = .clear
          attachment.storeAction = .dontCare
        }
      }

      commandBuffer.makeRenderCommandEncoder(descriptor: firstPass)!.configure {
        $0.setRenderPipelineState(self.firstPassPipeline)
        $0.setDepthStencilState(self.depthPipeline)
        for (index, vertexBuffer) in self.pikachuMesh.vertexBuffers.enumerated() {
          $0.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: index)
        }
        //$0.setCullMode(.back)
        //$0.setFrontFacing(.counterClockwise)
        $0.setFragmentTexture(self.pikacheTexture, index: 0)

        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        let modelTransform = float4x4(translate: [0, -0.92, 0]) * float4x4(scale: 0.17)
        let cameraTransform = float4x4(translate: [0, 0, -4])
        let projectionMatrix = float4x4(perspectiveWithAspect: aspectRatio, fovy: .τ / 12, near: 0.1, far: 100)
        var uniforms = ShaderUniforms(modelViewMatrix: cameraTransform * modelTransform, projectionMatrix: projectionMatrix)
        $0.setVertexBytes(&uniforms, length: MemoryLayout<ShaderUniforms>.size, index: 1)

        let submesh = self.pikachuMesh.submeshes[0]
        let indexBuffer = submesh.indexBuffer
        $0.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: indexBuffer.buffer, indexBufferOffset: indexBuffer.offset)
      }.endEncoding()

      commandBuffer.makeRenderCommandEncoder(descriptor: viewRenderDescriptor)!.configure {
        $0.setRenderPipelineState(self.secondPassPipeline)
        $0.setFragmentTexture(colorTexture, index: 0)
        let vertextData: [Float] = [
          -1, -1,  0,  1,
          -1,  1,  0,  0,
           1, -1,  1,  1,
           1,  1,  1,  0
        ]
        $0.setVertexBytes(vertextData, length: 16 * 4, index: 0)
        $0.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
      }.endEncoding()

      guard let drawable = view.currentDrawable else { return }
      commandBuffer.present(drawable)
      commandBuffer.commit()
    }
  }

  func setExercise(_ exercise: Exercise, view: MTKView) {
    guard self.exercise != exercise else { return }
    self.exercise = exercise
    self.secondPassDescriptor.fragmentFunction = library.makeFunction(name: exercise.shaderFunctionName)
    self.secondPassPipeline = try! device.makeRenderPipelineState(descriptor: self.secondPassDescriptor)
    view.setNeedsDisplay(view.bounds)
  }
}

private extension PikachuRenderer {
  static var id: String { "renderer.pikachu" }
}

extension Exercise {
  var shaderFunctionName: String {
    switch self {
    case .passthrough: "second_passthrough"
    case .mirror: "second_mirror"
    case .symmetry: "second_symmetry"
    case .rotation: "second_rotation"
    case .zoom: "second_zoom"
    case .zoomDistortion: "second_zoomDistortion"
    case .repetition: "second_repetitions"
    case .spiral: "second_spiral"
    case .thunder: "second_thunder"
    }
  }
}
