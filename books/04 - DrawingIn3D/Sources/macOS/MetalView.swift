import Cocoa
import Metal
import simd

protocol MetalViewDelegate {
  /// This method is called once per frame. Within the method, you may access any of the properties of the view, and request the current render pass descriptor to get a descriptor configured with renderable color and depth textures.
  func draw(view metalView: MetalView)
}

final class MetalView: NSView {
  /// Texture containing the depth data from the depth/stencil test.
  private var _depthTexture: MTLTexture?
  /// Timer sync with the screen refresh controlling when the drawing loop is fired.
  private var _displayLink: CVDisplayLink?
  /// The target frame rate (in Hz). For best results, this should be a number that evenly divides 60 (e.g., 60, 30, 15).
  private let _preferredFramesPerSecond: UInt = 60
  /// Helper for the CVDisplayLink instance
  private var _previousTimeStamp: UInt64 = CVGetCurrentHostTime()
  /// The duration (in seconds) of the previous frame. This is valid only in the context of a callback to the delegate's `draw(view:)` method.
  var frameDuration: TimeInterval = 1 / 60
  /// The color to which the color attachment should be cleared at the start of a rendering pass.
  let clearColor = MTLClearColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
  /// The view's layer's current drawable. This is valid only in the context of a callback to the delegate's `draw(view:)` method.
  var currentDrawable: CAMetalDrawable?
  /// The delegate of this view, responsible for drawing.
  var delegate: MetalViewDelegate?

  init(frame: NSRect, device: MTLDevice) {
    super.init(frame: frame)

    // Setup layer (layer-hosting)
    self.layer = CAMetalLayer().set { (layer) in
      layer.device = device
      layer.pixelFormat = .bgra8Unorm   // 8-bit unsigned integer [0, 255]
      layer.framebufferOnly = true
    }
    self.wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  /// The metal layer that backs this view.
  var metalLayer: CAMetalLayer {
    self.layer as! CAMetalLayer
  }

  /// A render pass descriptor configured to use the current drawable's texture as its primary color attachment and an internal depth texture of the same size as its depth attachment's texture.
  var currentRenderPassDescriptor: MTLRenderPassDescriptor? {
    guard let drawable = self.currentDrawable,
          let depthTexture = self._depthTexture else { return nil }

    return MTLRenderPassDescriptor().set { (renderPass) in
      renderPass.colorAttachments[0].setUp { (attachment) in
        attachment.texture = drawable.texture
        attachment.clearColor = clearColor
        attachment.loadAction = .clear
        attachment.storeAction = .store
      }
      renderPass.depthAttachment.setUp { (attachment) in
        attachment.texture = depthTexture
        attachment.clearDepth = 1
        attachment.loadAction = .clear
        attachment.storeAction = .dontCare
      }
    }
  }
  /// The layer used by this view (`CAMetalLayer`).
  override func makeBackingLayer() -> CALayer {
    CAMetalLayer()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    func callback(_ displayLink: CVDisplayLink, _ inNow: UnsafePointer<CVTimeStamp>, _ inOutputTime: UnsafePointer<CVTimeStamp>, _ flagsIn: CVOptionFlags, _ flagsOut: UnsafeMutablePointer<CVOptionFlags>, _ displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
      guard let context = displayLinkContext else { return kCVReturnInvalidArgument }
      let view = unsafeBitCast(context, to: MetalView.self)

      let futureTimeStamp = inOutputTime.pointee.hostTime
      view.frameDuration = TimeInterval(futureTimeStamp-view._previousTimeStamp) / TimeInterval(NSEC_PER_SEC)
      view._previousTimeStamp = futureTimeStamp

      DispatchQueue.main.async { view._displayLinkDidFire() }
      return kCVReturnSuccess
    }

    guard let window = self.window else {
      guard let displayLink = self._displayLink else { return }
      self._displayLink = nil
      CVDisplayLinkStop(displayLink)
      return
    }

    self.metalLayer.contentsScale = window.backingScaleFactor
    if let dl = self._displayLink { CVDisplayLinkStop(dl) }

    guard CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &self._displayLink) == kCVReturnSuccess else { fatalError("Display Link could not be created") }
    CVDisplayLinkSetOutputCallback(self._displayLink!, callback, Unmanaged.passUnretained(self).toOpaque())

    self._previousTimeStamp = CVGetCurrentHostTime()
    CVDisplayLinkStart(self._displayLink!)
  }

  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    _resize()
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    _resize()
  }
}

private extension MetalView {
  /// The device executing the tasks for the layer.
  var _device: MTLDevice {
    self.metalLayer.device!
  }

  func _resize() {
    // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels.
    let size = convertToBacking(bounds).size

    // If there are no changes on the width and height of the depth texture, don't recreate it.
    let w = Int(size.width), h = Int(size.height)
    guard self._depthTexture == nil || self._depthTexture!.width != w || self._depthTexture!.height != h else { return }

    self.metalLayer.drawableSize = size

    let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(size.width), height: Int(size.height), mipmapped: false).set {
      $0.storageMode = .`private`
      $0.usage = .renderTarget
    }
    self._depthTexture = self._device.makeTexture(descriptor: depthDescriptor)
  }

  func _displayLinkDidFire() {
    autoreleasepool {
      self.currentDrawable = self.metalLayer.nextDrawable()
      self.delegate?.draw(view: self)
    }
  }
}
