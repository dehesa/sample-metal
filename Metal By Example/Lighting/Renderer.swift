import Metal
import MetalKit
import ModelIO
import simd

@MainActor final class TeapotRenderer: NSObject, MTKViewDelegate {
  let device: MTLDevice
  private let queue: MTLCommandQueue
  private let renderPipeline: MTLRenderPipelineState
  private let depthPipeline: MTLDepthStencilState
  private var depthTexture: MTLTexture?
  private let meshes: [MTKMesh]
  private let uniformsBuffer: MTLBuffer
  private var uniforms: Uniforms?

  init?(device: MTLDevice) {
    self.device = device

    guard let commandQueue = device.makeCommandQueue() else { return nil }
    self.queue = commandQueue.configure { $0.label = .identifier(Self.id, "queue") }

    guard let library = device.makeDefaultLibrary(),
          let vertexFunc = library.makeFunction(name: "main_vertex"),
          let fragmentFunc = library.makeFunction(name: "main_fragment") else { return nil }

    let renderDescriptor = MTLRenderPipelineDescriptor().configure {
      $0.label = .identifier(Self.id, "pipeline.render")
      $0.vertexFunction = vertexFunc
      $0.vertexDescriptor = MTLVertexDescriptor().configure {
        $0.attributes[0].configure { attribute in
          attribute.bufferIndex = 0
          attribute.offset = 0
          attribute.format = .float3
        }
        $0.attributes[1].configure { attribute in
          attribute.bufferIndex = 0
          attribute.offset = MemoryLayout<Float>.stride * 3
          attribute.format = .float4
        }
        $0.layouts[0].stride = MemoryLayout<Float>.stride * 7
      }
      $0.fragmentFunction = fragmentFunc
      $0.colorAttachments[0].pixelFormat = .bgra8Unorm
      $0.depthAttachmentPixelFormat = .depth32Float
    }
    guard let renderPipeline = try? device.makeRenderPipelineState(descriptor: renderDescriptor) else { return nil }
    self.renderPipeline = renderPipeline

    let depthDescriptor = MTLDepthStencilDescriptor().configure {
      $0.label = .identifier(Self.id, "pipeline.depthStencil")
      $0.depthCompareFunction = .less
      $0.isDepthWriteEnabled = true
    }
    guard let depthPipeline = device.makeDepthStencilState(descriptor: depthDescriptor) else { return nil }
    self.depthPipeline = depthPipeline

    let modelDescriptor = MTKModelIOVertexDescriptorFromMetal(renderDescriptor.vertexDescriptor!).configure {
      ($0.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
      ($0.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
    }
    guard let url = Bundle.main.url(forResource: "teapot", withExtension: "obj") else { return nil }
    let asset = MDLAsset(url: url, vertexDescriptor: modelDescriptor, bufferAllocator: MTKMeshBufferAllocator(device: device))
    guard let meshes = try? MTKMesh.newMeshes(asset: asset, device: device).metalKitMeshes else { return nil }
    self.meshes = meshes

    guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<ShaderUniforms>.stride) else { return nil }
    self.uniformsBuffer = uniformBuffer.configure {
      $0.label = .identifier(Self.id, "buffers.uniform")
      $0.contents().bindMemory(to: ShaderUniforms.self, capacity: 1)
    }
  }

  nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    MainActor.assumeIsolated {
      let (width, height) = (Int(size.width), Int(size.height))
      guard width > .zero, height > .zero else {
        self.depthTexture = .none
        return
      }

      let isDifferent = self.depthTexture.map { $0.width != width || $0.height != height } ?? true
      guard isDifferent else { return }

      let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false).configure {
        $0.storageMode = .private
        $0.usage = .renderTarget
      }

      guard let texture = self.device.makeTexture(descriptor: descriptor) else {
        self.depthTexture = .none
        return
      }

      self.depthTexture = texture.configure {
        $0.label = .identifier(Self.id, "texture.depth")
      }
    }
  }

  nonisolated func draw(in view: MTKView) {
    MainActor.assumeIsolated {
      guard let depthTexture,
            let mesh = self.meshes.first,
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor else { return }

      descriptor.configure {
        $0.colorAttachments[0].configure {
          $0.texture = drawable.texture
          $0.clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1)
          $0.loadAction = .clear
          $0.storeAction = .store
        }
        $0.depthAttachment.configure {
          $0.texture = depthTexture
          $0.clearDepth = 1
          $0.loadAction = .clear
          $0.storeAction = .dontCare
        }
      }

      guard let commandBuffer = self.queue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

      self.uniforms = Uniforms(self.uniforms)
      let matrix = self.uniforms!.matrices(size: drawable.layer.drawableSize)
      self.uniformsBuffer.contents()
        .assumingMemoryBound(to: ShaderUniforms.self)
        .pointee = ShaderUniforms(modelViewProjectionMatrix: matrix.projection, modelViewMatrix: matrix.modelView, normalMatrix: matrix.normal)

      do {
        encoder.setRenderPipelineState(self.renderPipeline)
        encoder.setDepthStencilState(self.depthPipeline)
        encoder.setCullMode(.back)
        encoder.setFrontFacing(.counterClockwise)

        let vertexBuffer = mesh.vertexBuffers[0]
        encoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
        encoder.setVertexBuffer(self.uniformsBuffer, offset: 0, index: 1)

        guard let submesh = mesh.submeshes.first else { fatalError("Submesh not found.") }
        encoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)

        encoder.endEncoding()
      }

      commandBuffer.present(drawable)
      commandBuffer.commit()
    }
  }
}

private extension TeapotRenderer {
  static var id: String { "renderer.teapot" }

  struct Uniforms {
    let startTimestamp: Date
    let lastTimestamp: Date
    let rotation: (x: Float, y: Float)

    init(_ previous: Self?) {
      if let previous {
        self.startTimestamp = previous.startTimestamp
        self.lastTimestamp = Date()

        let duration = Float(self.lastTimestamp.timeIntervalSince(self.startTimestamp))
        self.rotation.x = duration * (.τ / 4.0)
        self.rotation.y = duration * (.τ / 6.0)

      } else {
        self.startTimestamp = Date()
        self.lastTimestamp = self.startTimestamp
        self.rotation = (.zero, .zero)
      }
    }

    func matrices(size: CGSize) -> (modelView: float4x4, projection: float4x4, normal: float3x3) {
      let scaleMatrix = float4x4(scale: 1)
      let xRotMatrix  = float4x4(rotate: SIMD3<Float>(1, 0, 0), angle: self.rotation.x)
      let yRotMatrix  = float4x4(rotate: SIMD3<Float>(0, 1, 0), angle: self.rotation.y)

      let modelMatrix = (yRotMatrix * xRotMatrix) * scaleMatrix
      let viewMatrix = float4x4(translate: [0, 0, -1])
      let projectionMatrix = float4x4(perspectiveWithAspect: Float(size.width)/Float(size.height), fovy: .τ/5, near: 0.1, far: 100)

      let modelViewMatrix = viewMatrix * modelMatrix
      let modelViewProjectionMatrix = projectionMatrix * modelViewMatrix
      let normalMatrix: float3x3 = { (m: float4x4) in
        let x = m.columns.0.xyz
        let y = m.columns.1.xyz
        let z = m.columns.2.xyz
        return float3x3(x, y, z)
      }(modelViewMatrix)

      return (modelViewMatrix, modelViewProjectionMatrix, normalMatrix)
    }
  }
}
