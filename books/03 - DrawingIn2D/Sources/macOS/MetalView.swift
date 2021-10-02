import Cocoa
import Metal

/// `NSView` handling the first basic metal commands.
final class MetalView: NSView {
  private let _device: MTLDevice
  private let _queue: MTLCommandQueue
  private let _vertexBuffer: MTLBuffer
  private let _renderPipeline: MTLRenderPipelineState

  init?(frame: NSRect, device: MTLDevice, queue: MTLCommandQueue) {
    // Setup the Device and Command Queue (non-transient objects: expensive to create. Do save it)
    self._device = device
    self._queue = queue
    self._queue.label = App.bundleIdentifier + ".queue"

    // Setup shader library
    guard let library = device.makeDefaultLibrary(),
          let vertexFunc = library.makeFunction(name: "main_vertex"),
          let fragmentFunc = library.makeFunction(name: "main_fragment") else { return nil }

    // Setup pipeline (non-transient)
    let pipelineDescriptor = MTLRenderPipelineDescriptor().set {
      $0.vertexFunction = vertexFunc
      $0.fragmentFunction = fragmentFunc
      $0.colorAttachments[0].pixelFormat = .bgra8Unorm   // 8-bit unsigned integer [0, 255]
    }
    guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else { return nil }
    self._renderPipeline = pipelineState

    // Setup buffer (non-transient). Coordinates defined in clip space: [-1,+1]
    let vertices = [_Vertex(position: [ 0.0,  0.5, 0, 1], color: [1,0,0,1]),
                    _Vertex(position: [-0.5, -0.5, 0, 1], color: [0,1,0,1]),
                    _Vertex(position: [ 0.5, -0.5, 0, 1], color: [0,0,1,1]) ]
    let size = vertices.count * MemoryLayout<_Vertex>.stride
    guard let buffer = device.makeBuffer(bytes: vertices, length: size, options: .cpuCacheModeWriteCombined) else { return nil }
    self._vertexBuffer = buffer.set { $0.label = App.bundleIdentifier + ".buffer" }

    super.init(frame: frame)

    // Setup layer (backing layer)
    self.wantsLayer = true
    self._metalLayer.setUp { (layer) in
      layer.device = device
      layer.pixelFormat = .bgra8Unorm
      layer.framebufferOnly = true
    }
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  override func makeBackingLayer() -> CALayer {
    CAMetalLayer()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    guard let window = self.window else { return }
    self._metalLayer.contentsScale = window.backingScaleFactor
    self._redraw()
  }

  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    self._metalLayer.drawableSize = convertToBacking(bounds).size
    self._redraw()
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    self._metalLayer.drawableSize = convertToBacking(bounds).size
    self._redraw()
  }
}

extension MetalView {
  private struct _Vertex {
    var position: SIMD4<Float>
    var color: SIMD4<Float>
  }

  var _metalLayer: CAMetalLayer {
    self.layer as! CAMetalLayer
  }

  /// Draws a triangle in the metal layer drawable.
  private func _redraw() {
    // Setup Command Buffer (transient)
    guard let drawable = self._metalLayer.nextDrawable(),
          let commandBuffer = self._queue.makeCommandBuffer() else { return }

    let renderPass = MTLRenderPassDescriptor().set {
      $0.colorAttachments[0].setUp { (attachment) in
        attachment.texture = drawable.texture
        attachment.clearColor = MTLClearColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        attachment.loadAction = .clear
        attachment.storeAction = .store
      }
    }

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
    encoder.setRenderPipelineState(self._renderPipeline)
    encoder.setVertexBuffer(self._vertexBuffer, offset: 0, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()

    // Present drawable is a convenience completion block that will get executed once your command buffer finishes, and will output the final texture to screen.
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
