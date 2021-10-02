import Cocoa
import Metal

/// `NSView` handling the first basic metal commands.
final class MetalView: NSView {
  private let _device: MTLDevice
  private let _queue: MTLCommandQueue

  init(frame: NSRect, device: MTLDevice, queue: MTLCommandQueue) {
    // Setup the Device and Command Queue (non-transient objects: expensive to create. Do save it)
    (self._device, self._queue) = (device, queue)
    self._queue.label = App.bundleIdentifier + ".queue"
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
    self._metalLayer.drawableSize = self.convertToBacking(bounds).size
    self._redraw()
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    self._metalLayer.drawableSize = convertToBacking(bounds).size
    self._redraw()
  }
}

private extension MetalView {
  var _metalLayer: CAMetalLayer {
    layer as! CAMetalLayer
  }

  /// Fills the metal layer with a solid color.
  func _redraw() {
    // Setup Command Buffer (transient)
    guard let drawable = self._metalLayer.nextDrawable(),
          let commandBuffer = self._queue.makeCommandBuffer() else { return }

    // Setup the render pass descriptor.
    let renderPass = MTLRenderPassDescriptor().set {
      $0.colorAttachments[0].setUp { (attachment) in
        attachment.texture = drawable.texture
        attachment.clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1)
        attachment.loadAction = .clear
        attachment.storeAction = .store
      }
    }

    // Setup Command Encoder (transient)
    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
    encoder.endEncoding()

    // Present drawable is a convenience completion block that will get executed once your command buffer finishes, and will output the final texture to screen.
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
