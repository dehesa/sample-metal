import Metal
import MetalKit
import ModelIO
import simd

final class CowRenderer: NSObject, MTKViewDelegate {
  private let _device: MTLDevice
  private let _commandQueue: MTLCommandQueue
  private let _state: (render: MTLRenderPipelineState, depth: MTLDepthStencilState)
  private let _uniformsBuffer: MTLBuffer
  private let _diffuseTexture: MTLTexture
  private let _samplerTexture: MTLSamplerState
  private let _meshes: [MTKMesh]
  private var (_time, _rotationX, _rotationY): (Float, Float, Float) = (0,0,0)

  init(view: MTKView) throws {
    // Create GPU representation (MTLDevice) and Command Queue.
    guard let device = MTLCreateSystemDefaultDevice() else { throw _Error.failedToCreateMetalDevice }
    guard let commandQueue = device.makeCommandQueue() else { throw _Error.failedToCreateMetalCommandQueue(device: device) }
    (self._device, self._commandQueue) = (device, commandQueue)

    // Creates the render states
    let pixelFormats: _PixelFormats = (.bgra8Unorm, .depth32Float)
    let descriptors = try CowRenderer._makeStateDescriptors(device: device, pixelFormats: pixelFormats)
    let renderPipelineState = try device.makeRenderPipelineState(descriptor: descriptors.renderPipeline)
    guard let depthStencilState = device.makeDepthStencilState(descriptor: descriptors.depthStencil) else { throw _Error.failedToCreateDepthStencilState(device: device) }
    self._state = (renderPipelineState, depthStencilState)

    /// Creates the texture and meshes from the external models.
    self._meshes = try CowRenderer._makeMeshes(device: device, vertexDescriptor: descriptors.renderPipeline.vertexDescriptor!)
    (self._diffuseTexture, self._samplerTexture) = try CowRenderer.makeTexture(device: device)

    // Create buffers used in the shader
    guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<_Uniforms>.stride) else { throw _Error.failedToCreateMetalBuffer(device: device) }
    uniformBuffer.label = "io.dehesa.metal.buffers.uniform"
    uniformBuffer.contents().bindMemory(to: _Uniforms.self, capacity: 1)
    self._uniformsBuffer = uniformBuffer

    // Setup the MTKView.
    view.setUp {
      ($0.device, $0.clearColor) = (device, MTLClearColorMake(0, 0, 0, 1))
      ($0.colorPixelFormat, $0.depthStencilPixelFormat) = pixelFormats
    }
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    guard let mesh = _meshes.first,
          let drawable = view.currentDrawable,
          let descriptor = view.currentRenderPassDescriptor else { return }

    descriptor.setUp {
      $0.colorAttachments[0].texture = drawable.texture
      $0.colorAttachments[0].loadAction = .clear
      $0.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1)
    }

    guard let commandBuffer = self._commandQueue.makeCommandBuffer(),
          let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

    let drawableSize = drawable.layer.drawableSize.float2
    _updateUniforms(drawableSize: drawableSize, duration: Float(1.0 / 60.0))

    do {
      encoder.setRenderPipelineState(self._state.render)
      encoder.setDepthStencilState(self._state.depth)
      encoder.setCullMode(.back)
      encoder.setFrontFacing(.counterClockwise)

      let vertexBuffer = mesh.vertexBuffers[0]
      encoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
      encoder.setVertexBuffer(self._uniformsBuffer, offset: 0, index: 1)
      encoder.setFragmentTexture(self._diffuseTexture, index: 0)
      encoder.setFragmentSamplerState(self._samplerTexture, index: 0)

      guard let submesh = mesh.submeshes.first else { fatalError("Submesh not found.") }
      encoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)

      encoder.endEncoding()
    }

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}

private extension CowRenderer {
  struct _Uniforms {
    var modelViewProjectionMatrix: float4x4
    var modelViewMatrix: float4x4
    var normalMatrix: float3x3
  }

  enum _Error: Swift.Error {
    case failedToCreateMetalDevice
    case failedToCreateMetalCommandQueue(device: MTLDevice)
    case failedToCreateMetalLibrary(device: MTLDevice)
    case failedToCreateShaderFunction(name: String)
    case failedToCreateDepthStencilState(device: MTLDevice)
    case failedToFoundFile(name: String)
    case failedToCreateMetalBuffer(device: MTLDevice)
    case failedToCreateMetalSampler(device: MTLDevice)
  }

  /// Pixel formats used by the renderer.
  typealias _PixelFormats = (color: MTLPixelFormat, depth: MTLPixelFormat)

  /// Creates the descriptors for the render pipeline state and depth stencil state.
  static func _makeStateDescriptors(device: MTLDevice, pixelFormats: _PixelFormats) throws -> (renderPipeline: MTLRenderPipelineDescriptor, depthStencil: MTLDepthStencilDescriptor) {
    // Initialize the library and respective metal functions.
    let functionName: (vertex: String, fragment: String) = ("main_vertex", "main_fragment")
    guard let library = device.makeDefaultLibrary() else { throw _Error.failedToCreateMetalLibrary(device: device) }
    guard let vertexFunction = library.makeFunction(name: functionName.vertex) else { throw _Error.failedToCreateShaderFunction(name: functionName.vertex) }
    guard let fragmentFunction = library.makeFunction(name: functionName.fragment) else { throw _Error.failedToCreateShaderFunction(name: functionName.fragment) }

    // Define both states (render and depth-stencil).
    let renderPipelineDescriptor = MTLRenderPipelineDescriptor().set { (pipeline) in
      pipeline.vertexFunction = vertexFunction
      pipeline.vertexDescriptor = MTLVertexDescriptor().set {
        $0.attributes[0].setUp { (attribute) in
          attribute.bufferIndex = 0
          attribute.offset = 0
          attribute.format = .float3
        }
        $0.attributes[1].setUp { (attribute) in
          attribute.bufferIndex = 0
          attribute.offset = MemoryLayout<Float>.stride * 3
          attribute.format = .float4
        }
        $0.attributes[2].setUp { (attribute) in
          attribute.bufferIndex = 0
          attribute.offset = MemoryLayout<Float>.stride * 7
          attribute.format = .float2
        }
        $0.layouts[0].stride = MemoryLayout<Float>.stride * 9
      }

      pipeline.fragmentFunction = fragmentFunction
      pipeline.colorAttachments[0].pixelFormat = pixelFormats.color
      pipeline.depthAttachmentPixelFormat = pixelFormats.depth
    }

    let depthStencilStateDescriptor = MTLDepthStencilDescriptor().set { (state) in
      state.depthCompareFunction = .less
      state.isDepthWriteEnabled = true
    }

    return (renderPipelineDescriptor, depthStencilStateDescriptor)
  }

  /// Initializes the asset from the external model
  static func _makeMeshes(device: MTLDevice, vertexDescriptor: MTLVertexDescriptor) throws -> [MTKMesh] {
    let file: (name: String, `extension`: String) = ("spot", "obj")
    guard let url = Bundle.main.url(forResource: file.name, withExtension: file.`extension`) else { throw _Error.failedToFoundFile(name: "\(file.name).\(file.`extension`)") }

    let modelDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor).set {
      ($0.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
      ($0.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
      ($0.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
    }

    let asset = MDLAsset(url: url, vertexDescriptor: modelDescriptor, bufferAllocator: MTKMeshBufferAllocator(device: device))
    return try MTKMesh.newMeshes(asset: asset, device: device).metalKitMeshes
  }

  /// Initializes a texture buffer from an external image.
  private static func makeTexture(device: MTLDevice) throws -> (texture: MTLTexture, sampler: MTLSamplerState) {
    let file: (name: String, `extension`: String) = ("spot_texture", "png")
    guard let url = Bundle.main.url(forResource: file.name, withExtension: file.`extension`) else { throw _Error.failedToFoundFile(name: "\(file.name).\(file.`extension`)") }

    let loader = MTKTextureLoader(device: device)
    let texture = try loader.newTexture(URL: url, options: [.origin: MTKTextureLoader.Origin.bottomLeft, .generateMipmaps: true])

    let samplerDescriptor = MTLSamplerDescriptor().set {
      ($0.sAddressMode, $0.tAddressMode) = (.clampToEdge, .clampToEdge)
      ($0.minFilter, $0.magFilter, $0.mipFilter) = (.nearest, .linear, .linear)
    }
    guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else { throw _Error.failedToCreateMetalSampler(device: device) }
    return (texture, sampler)
  }

  /// Updates the internal values with the passed arguments.
  func _updateUniforms(drawableSize size: SIMD2<Float>, duration: Float) {
    self._time += duration
    self._rotationX += duration * (.𝝉 / 4.0)
    self._rotationY += duration * (.𝝉 / 6.0)

    let scaleMatrix = float4x4(scale: 1)
    let xRotMatrix  = float4x4(rotate: SIMD3<Float>(1, 0, 0), angle: self._rotationX)
    let yRotMatrix  = float4x4(rotate: SIMD3<Float>(0, 1, 0), angle: self._rotationX)

    let modelMatrix = (yRotMatrix * xRotMatrix) * scaleMatrix
    let viewMatrix = float4x4(translate: [0, 0, -1.25])
    let projectionMatrix = float4x4(perspectiveWithAspect: size.x/size.y, fovy: .𝝉/5, near: 0.1, far: 100)

    let modelViewMatrix = viewMatrix * modelMatrix
    let modelViewProjectionMatrix = projectionMatrix * modelViewMatrix
    let normalMatrix: float3x3 = { (m: float4x4) in
      let x = m.columns.0.xyz
      let y = m.columns.1.xyz
      let z = m.columns.2.xyz
      return float3x3(x, y, z)
    }(modelViewMatrix)

    let ptr = _uniformsBuffer.contents().assumingMemoryBound(to: _Uniforms.self)
    ptr.pointee = _Uniforms(modelViewProjectionMatrix: modelViewProjectionMatrix, modelViewMatrix: modelViewMatrix, normalMatrix: normalMatrix)
  }
}

