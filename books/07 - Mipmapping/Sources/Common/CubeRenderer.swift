import Metal
import MetalKit
import ModelIO
import simd

final class CubeRenderer: NSObject, MTKViewDelegate {
  private let _device: MTLDevice
  private let _commandQueue: MTLCommandQueue
  private let _state: (render: MTLRenderPipelineState, depth: MTLDepthStencilState)
  private let _buffers: (vertices: MTLBuffer, indices: MTLBuffer, uniforms: MTLBuffer)
  private var _textures: _CubeTextures
  private let _samplers: _CubeSamplers
  private var _angles: (x: Float, y: Float) = (0, 0)

  var mipmapMode = MipmapMode.none
  var cameraDistance: Float = 1.0

  init(view: MTKView) throws {
    // 1. Create GPU representation (MTLDevice) and Command Queue.
    guard let device = MTLCreateSystemDefaultDevice() else { throw _Error.failedToCreateMetalDevice }
    guard let commandQueue = device.makeCommandQueue() else { throw _Error.failedToCreateMetalCommandQueue(device: device) }
    (self._device, self._commandQueue) = (device, commandQueue)

    // 2. Creates the render states
    let pixelFormats: _PixelFormats = (.bgra8Unorm, .depth32Float)
    let descriptors = try CubeRenderer._makeStateDescriptors(device: device, pixelFormats: pixelFormats)
    let renderPipelineState = try device.makeRenderPipelineState(descriptor: descriptors.renderPipeline)
    guard let depthStencilState = device.makeDepthStencilState(descriptor: descriptors.depthStencil) else { throw _Error.failedToCreateDepthStencilState(device: device) }
    self._state = (renderPipelineState, depthStencilState)

    // 3. Create buffers used in the shader
    let mesh = try Generator.Cube.makeBuffers(device: device, size: 1.0)
    guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<_Uniforms>.stride) else { throw _Error.failedToCreateMetalBuffers(device: device) }
    uniformBuffer.label = "io.dehesa.metal.buffers.uniform"
    self._buffers = (mesh.vertices, mesh.indices, uniformBuffer)

    // 4. Create the textures.
    let board: (size: CGSize, tileCount: Int) = (CGSize(width: 512, height: 512), 8)
    let checkerTexture = try Generator.Texture.makeSimpleCheckerboard(size: board.size, tileCount: board.tileCount, pixelFormat: pixelFormats.color, with: (device, commandQueue))
    let vibrantTexture = try Generator.Texture.makeTintedCheckerboard(size: board.size, tileCount: board.tileCount, pixelFormat: pixelFormats.color, with: device)
    let depthTexture = try Generator.Texture.makeDepth(size: view.drawableSize, pixelFormat: pixelFormats.depth, with: device)
    self._textures = (checkerTexture, vibrantTexture, depthTexture)

    // 5. Create the samplers
    self._samplers = try Generator.Texture.makeSamplers(with: device)

    // 6. Setup the MTKView.
    view.setUp {
      ($0.device, $0.clearColor) = (device, MTLClearColorMake(0, 0, 0, 1))
      ($0.colorPixelFormat, $0.depthStencilPixelFormat) = pixelFormats
    }
  }


  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    let depthSize = CGSize(width: _textures.depth.width, height: _textures.depth.height)
    guard !size.equalTo(depthSize) else { return }
    self._textures.depth = try! Generator.Texture.makeDepth(size: size, pixelFormat: view.colorPixelFormat, with: _device)
  }


  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
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

      encoder.setVertexBuffer(self._buffers.vertices, offset: 0, index: 0)
      encoder.setVertexBuffer(self._buffers.uniforms, offset: 0, index: 1)

      let fragment = self.mipmapMode.selector(textures: self._textures, samplers: self._samplers)
      encoder.setFragmentTexture(fragment.texture, index: 0)
      encoder.setFragmentSamplerState(fragment.sampler, index: 0)

      let indicesCount = self._buffers.indices.length / MemoryLayout<Generator.Cube.Index>.stride
      encoder.drawIndexedPrimitives(type: .triangle, indexCount: indicesCount, indexType: .uint16, indexBuffer: self._buffers.indices, indexBufferOffset: 0)

      encoder.endEncoding()
    }

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  /// Enumeration for all the mipmapping options.
  enum MipmapMode: Int {
    case none = 0
    case blitGeneratedLinear
    case vibrantLinear
    case vibrantNearest

    var next: MipmapMode {
      let nextRawValue = (self.rawValue + 1) % (MipmapMode.last.rawValue + 1)
      return MipmapMode(rawValue: nextRawValue)!
    }

    private static var last: MipmapMode {
      return .vibrantNearest
    }

    fileprivate func selector(textures: _CubeTextures, samplers: _CubeSamplers) -> (texture: MTLTexture, sampler: MTLSamplerState) {
      switch self {
      case .none:                return (textures.checker, samplers.notMip)
      case .blitGeneratedLinear: return (textures.checker, samplers.linearMip)
      case .vibrantNearest:      return (textures.vibrant, samplers.nearestMip)
      case .vibrantLinear:       return (textures.vibrant, samplers.linearMip)
      }
    }
  }
}

private extension CubeRenderer {
  /// The uniform buffer passed to shader.
  struct _Uniforms {
    var modelMatrix: float4x4
    var modelViewProjectionMatrix: float4x4
    var normalMatrix: float3x3
  }

  /// Types of errors generated on this renderer.
  enum _Error: Swift.Error {
    case failedToCreateMetalDevice
    case failedToCreateMetalCommandQueue(device: MTLDevice)
    case failedToCreateMetalLibrary(device: MTLDevice)
    case failedToCreateShaderFunction(name: String)
    case failedToCreateDepthStencilState(device: MTLDevice)
    case failedToFoundFile(name: String)
    case failedToCreateMetalBuffers(device: MTLDevice)
  }

  /// All possible texture used by this renderer.
  typealias _CubeTextures = (checker: MTLTexture, vibrant: MTLTexture, depth: MTLTexture)
  /// All possible samplers used by this  renderer.
  typealias _CubeSamplers = (notMip: MTLSamplerState, nearestMip: MTLSamplerState, linearMip: MTLSamplerState)

  /// Pixel formats used by the renderer.
  typealias _PixelFormats = (color: MTLPixelFormat, depth: MTLPixelFormat)

  /// Creates the descriptors for the render pipeline state and depth stencil state.
  /// - parameter device: Metal device where the render pipeline will be created.
  /// - parameter pixelFormats: Pixel formats for the color and depth attachments.
  /// - returns: Fully constructer render pipeline (with vertex and fragment function) and the depth state.
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
          attribute.format = .float4
        }
        $0.attributes[1].setUp { (attribute) in
          attribute.bufferIndex = 0
          attribute.offset = MemoryLayout<Float>.stride * 4
          attribute.format = .float4
        }
        $0.attributes[2].setUp { (attribute) in
          attribute.bufferIndex = 0
          attribute.offset = MemoryLayout<Float>.stride * 8
          attribute.format = .float2
        }
        $0.layouts[0].setUp { (layout) in
          layout.stride = MemoryLayout<Float>.stride * 10
          layout.stepFunction = .perVertex
          layout.stepRate = 1
        }
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

  /// Updates the internal values with the passed arguments.
  func _updateUniforms(drawableSize size: SIMD2<Float>, duration: Float) {
    let cubePosition: SIMD3<Float> = [0, 0, 20]
    let modelMatrix = float4x4(translate: cubePosition) //* (float4x4(rotate: [1, 0, 0], angle: self.angles.x) * float4x4(rotate: [0, 1, 0], angle: self.angles.y))

    let cameraPosition: SIMD3<Float> = [0, 0, -1.25]
    //        let cameraPosition: float3 = [0, 0, -self.cameraDistance]
    let viewMatrix = float4x4(translate: cameraPosition)

    let fov: Float = (size.x / size.y) > 1 ? (.𝝉/6) : (.𝝉/4)
    let projectionMatrix = float4x4(perspectiveWithAspect: size.x/size.y, fovy: fov, near: 0.1, far: 100)

    let modelViewMatrix = viewMatrix * modelMatrix
    let modelViewProjectionMatrix = projectionMatrix * modelViewMatrix
    let normalMatrix: float3x3 = { (m: float4x4) in
      let x = m.columns.0.xyz
      let y = m.columns.1.xyz
      let z = m.columns.2.xyz
      return float3x3(x, y, z)
    }(modelViewMatrix)

    let ptr = self._buffers.uniforms.contents().assumingMemoryBound(to: _Uniforms.self)
    ptr.pointee = _Uniforms(modelMatrix: modelMatrix, modelViewProjectionMatrix: modelViewProjectionMatrix, normalMatrix: normalMatrix.inverse.transpose)
  }
}
