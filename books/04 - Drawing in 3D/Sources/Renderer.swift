import QuartzCore
import Metal
import simd

/// Conforming instances must be able to draw through Metal a frame in a given Core Animation Metal layer.
protocol Renderer: AnyObject {
  /// The GPU used for rendering.
  var device: MTLDevice { get }
  /// This function should perform a rendering call (or ignore the frame).
  ///
  /// The function will be called in a high-priority background thread. Be mindful of the amount of work performed here.
  /// Rendering calls should target a minimum of 60 fps; meaning this function will get call (at least) every 0.0166 seconds.
  /// - parameter layer: The target of the rendering call (i.e. the Core Animation layer where the frame will be displayed).
  /// - parameter time: The time received from timer synchronized to screen refresh.
  ///   Its values represent the seconds since the system bootup; `now` is the time when the timer got triggered, `display` is the time when the fram should be displayed on the screen.
  nonisolated func draw(layer: CAMetalLayer, time: (now: Double, display: Double))
}

/// A render that will draw a spinning cube.
final class CubeRenderer: Renderer {
  let device: MTLDevice
  private let queue: MTLCommandQueue
  private let renderPipeline: MTLRenderPipelineState
  private let depthPipeline: MTLDepthStencilState
  private let verticesBuffer: MTLBuffer
  private let indecesBuffer: MTLBuffer
  private let uniformsBuffer: MTLBuffer
  private var depthTexture: MTLTexture?

  private let lock = NSLock()
  private var numParallelRenders: Int = .zero
  private var uniforms: Uniforms?

  init?(device: MTLDevice) {
    self.device = device

    guard let queue = device.makeCommandQueue() else { return nil }
    self.queue = queue

    guard let library = device.makeDefaultLibrary(),
          let vertexFunc = library.makeFunction(name: "main_vertex"),
          let fragmentFunc = library.makeFunction(name: "main_fragment") else { return nil }

    let renderDescriptor = MTLRenderPipelineDescriptor().configure {
      $0.label = .identifier(Self.id, "pipeline.render")
      $0.vertexFunction = vertexFunc
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

    // Setup buffers. Coordinates defined in clip space coords: [-1,+1] for x and y; and [0,+1] for z.
    let vertices: [ShaderVertex] = [
      ShaderVertex(position: [-1,  1,  1, 1], color: [0, 1, 1, 1]), // left,  top,    back
      ShaderVertex(position: [-1, -1,  1, 1], color: [0, 0, 1, 1]), // left,  bottom, back
      ShaderVertex(position: [ 1, -1,  1, 1], color: [1, 0, 1, 1]), // right, bottom, back
      ShaderVertex(position: [ 1,  1,  1, 1], color: [1, 1, 1, 1]), // right, top,    back
      ShaderVertex(position: [-1,  1, -1, 1], color: [0, 1, 0, 1]), // left,  top,    front
      ShaderVertex(position: [-1, -1, -1, 1], color: [0, 0, 0, 1]), // left,  bottom, front
      ShaderVertex(position: [ 1, -1, -1, 1], color: [1, 0, 0, 1]), // right, bottom, front
      ShaderVertex(position: [ 1,  1, -1, 1], color: [1, 1, 0, 1])  // right, top,    front
    ]

    guard let verticesBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<ShaderVertex>.stride, options: .cpuCacheModeWriteCombined) else { return nil }
    self.verticesBuffer = verticesBuffer.configure { $0.label = .identifier(Self.id, "buffer.vertices") }

    let indices: [UInt16] = [
      3, 2, 6, 6, 7, 3,   4, 5, 1, 1, 0, 4,
      4, 0, 3, 3, 7, 4,   1, 5, 6, 6, 2, 1,
      0, 1, 2, 2, 3, 0,   7, 6, 5, 5, 4, 7
    ]

    guard let indicesBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: .cpuCacheModeWriteCombined) else { return nil }
    self.indecesBuffer = indicesBuffer.configure { $0.label = .identifier(Self.id, "buffer.indices") }

    guard let uniformsBuffer = device.makeBuffer(length: MemoryLayout<ShaderUniforms>.stride) else { return nil }
    self.uniformsBuffer = uniformsBuffer.configure { $0.label = .identifier(Self.id, "buffer.uniforms") }

    self.lock.name = .identifier(Self.id, "lock")
  }
}

extension CubeRenderer {
  func draw(layer: CAMetalLayer, time: (now: Double, display: Double)) {
    // Drop frames if we are already waiting for other frames to be processed.
    guard self.requestRenderPriviledge() else { return }

    guard let size = self.resizeIfNecessary(layer: layer),
          let depthTexture,
          let drawable = layer.nextDrawable(),
          let commandBuffer = queue.makeCommandBuffer() else {
      return releaseRenderPriviledge()
    }

    let passDescriptor = MTLRenderPassDescriptor().configure {
      $0.colorAttachments[0].configure {
        $0.texture = drawable.texture
        $0.clearColor = MTLClearColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
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

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
      return releaseRenderPriviledge()
    }

    switch self.uniforms {
    case let uni?: self.uniforms = Uniforms(uni, display: time.display)
    case .none: self.uniforms = Uniforms(now: time.now, display: time.display)
    }

    let ptr = self.uniformsBuffer.contents().assumingMemoryBound(to: ShaderUniforms.self)
    ptr.pointee = ShaderUniforms(mvpMatrix: self.uniforms!.projectionMatrix(size: size))

    encoder.configure {
      $0.setRenderPipelineState(self.renderPipeline)
      $0.setDepthStencilState(self.depthPipeline)
      $0.setFrontFacing(.counterClockwise)
      $0.setCullMode(.back)
      $0.setVertexBuffer(self.verticesBuffer, offset: 0, index: 0)
      $0.setVertexBuffer(self.uniformsBuffer, offset: 0, index: 1)
      $0.drawIndexedPrimitives(type: .triangle, indexCount: self.indecesBuffer.length / MemoryLayout<UInt16>.stride, indexType: .uint16, indexBuffer: self.indecesBuffer, indexBufferOffset: 0)
    }.endEncoding()

    commandBuffer.configure {
      $0.present(drawable)
      $0.addCompletedHandler { [weak self] _ in self?.releaseRenderPriviledge() }
    }.commit()
  }
}

private extension CubeRenderer {
  static var id: String { "renderer.cube" }
  static var maxParallelRenders: Int { 3 }

  func requestRenderPriviledge() -> Bool {
    self.lock.lock()
    defer { self.lock.unlock() }

    guard numParallelRenders + 1 < Self.maxParallelRenders else { return false }
    numParallelRenders += 1

    return true
  }

  func releaseRenderPriviledge() {
    self.lock.lock()
    defer { self.lock.unlock() }

    numParallelRenders -= 1
    precondition(numParallelRenders >= .zero, "Release render priviledges is 'over-called'")
  }

  func resizeIfNecessary(layer: CAMetalLayer) -> (width: Int, height: Int)? {
    let drawableSize: CGSize = [layer.bounds.size.width * layer.contentsScale, layer.bounds.size.height * layer.contentsScale]
    let (width, height) = (Int(drawableSize.width), Int(drawableSize.height))

    if width != Int(layer.drawableSize.width) || height != Int(layer.drawableSize.height) {
      layer.drawableSize = [CGFloat(width), CGFloat(height)]
    }

    guard drawableSize.allSatisfy({ $0 > .zero }) else {
      self.depthTexture = .none
      return .none
    }

    let isDifferent = self.depthTexture.map { $0.width != width || $0.height != height } ?? true
    guard isDifferent else { return (width, height) }

    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false).configure {
      $0.storageMode = .private
      $0.usage = .renderTarget
    }

    guard let texture = self.device.makeTexture(descriptor: descriptor) else {
      self.depthTexture = .none
      return .none
    }

    self.depthTexture = texture.configure {
      $0.label = .identifier(Self.id, "texture.depth")
    }
    return (width, height)
  }

  struct Uniforms {
    let startTimestamp: Double
    let lastTimestamp: Double
    let rotation: (x: Float, y: Float)

    init(now: Double, display: Double) {
      self.startTimestamp = now
      self.lastTimestamp = display

      let duration = display - now
      self.rotation.x = Float(duration * Double.𝝉 / 4)
      self.rotation.y = Float(duration * Double.𝝉 / 6)
    }

    init(_ previous: Self, display: Double) {
      self.startTimestamp = previous.startTimestamp
      self.lastTimestamp = display

      let duration = display - startTimestamp
      self.rotation.x = Float(duration * Double.𝝉 / 4)
      self.rotation.y = Float(duration * Double.𝝉 / 6)
    }

    func projectionMatrix(size: (width: Int, height: Int)) -> float4x4 {
      let aspectRatio = Float(size.width) / Float(size.height)
      let duration = Float(lastTimestamp - startTimestamp)

      let scaleFactor: Float = 1 + 0.25 * sin(5 * duration)
      let xRotMatrix = float4x4(rotate: [1, 0, 0], angle: self.rotation.x)
      let yRotMatrix = float4x4(rotate: [0, 1, 0], angle: self.rotation.y)
      let scaleMatrix = float4x4(diagonal: [scaleFactor, scaleFactor, scaleFactor, 1])
      let modelMatrix = yRotMatrix * (xRotMatrix * scaleMatrix)
      // Move the camera 8 units on the -z axis.
      // Equal to push object 8 units on +z axis direction.
      let viewMatrix = float4x4(translate: [0, 0, -8])
      let projectionMatrix = float4x4(perspectiveWithAspect: aspectRatio, fovy: Float.π/5, near: 1, far: 100)

      return projectionMatrix * (viewMatrix * modelMatrix)
    }
  }
}
