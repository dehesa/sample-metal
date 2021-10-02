import UIKit
import Metal
import simd

protocol MetalViewDelegate {
  /// This method is called once per frame. Within the method, you may access any of the properties of the view, and request the current render pass descriptor to get a descriptor configured with renderable color and depth textures.
  func draw(view metalView: MetalView)
}

final class MetalView: UIView {
  /// Texture containing the depth data from the depth/stencil test.
  private var _depthTexture: MTLTexture?
  /// Timer sync with the screen refresh controlling when the drawing loop is fired.
  private var _displayLink: CADisplayLink?
  /// The target frame rate (in Hz). For best results, this should be a number that evenly divides 60 (e.g., 60, 30, 15).
  private let _preferredFramesPerSecond: UInt = 60
  /// The duration (in seconds) of the previous frame. This is valid only in the context of a callback to the delegate's `draw(view:)` method.
  var frameDuration: TimeInterval = 1 / 60
  /// The color to which the color attachment should be cleared at the start of a rendering pass.
  let clearColor: MTLClearColor = MTLClearColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
  /// The view's layer's current drawable. This is valid only in the context of a callback to the delegate's `draw(view:)` method.
  var currentDrawable: CAMetalDrawable?
  /// The delegate of this view, responsible for drawing.
  var delegate: MetalViewDelegate?

  init(frame: CGRect, device: MTLDevice) {
    super.init(frame: frame)
    self.metalLayer.setUp {
      $0.device = device
      $0.pixelFormat = .bgra8Unorm    // 8-bit unsigned integer [0, 255]
      $0.framebufferOnly = true
    }
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  /// The metal layer that backs this view.
  var metalLayer: CAMetalLayer {
    self.layer as! CAMetalLayer
  }

  /// The layer used by this view (`CAMetalLayer`).
  override static var layerClass: AnyClass {
    CAMetalLayer.self
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

  override func didMoveToWindow() {
    super.didMoveToWindow()

    self._displayLink?.invalidate()
    guard let window = self.window else {
      return self._displayLink = nil
    }

    self.metalLayer.contentsScale = window.screen.scale
    self._displayLink = CADisplayLink(target: self, selector: #selector(MetalView._tickTrigger(from:))).set {
      $0.preferredFramesPerSecond = Int(self._preferredFramesPerSecond)
      $0.add(to: .main, forMode: .common)
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels.
    let scale = self.metalLayer.contentsScale
    let size = self.bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))

    // If there are no changes on the width and height of the depth texture, don't recreate it.
    if let texture = self._depthTexture,
       CGSize(width: texture.width, height: texture.height).equalTo(size) { return }

    self.metalLayer.drawableSize = size

    let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(size.width), height: Int(size.height), mipmapped: false).set {
      $0.storageMode = .`private`
      $0.usage = .renderTarget
    }
    self._depthTexture = self._device.makeTexture(descriptor: depthDescriptor)
  }
}

private extension MetalView {
  /// The device executing the tasks for the layer.
  var _device: MTLDevice {
    self.metalLayer.device!
  }

  @objc func _tickTrigger(from displayLink: CADisplayLink) {
    self.currentDrawable = metalLayer.nextDrawable()
    self.frameDuration = displayLink.duration
    self.delegate?.draw(view: self)
  }
}
