#if os(macOS)
import Cocoa
#elseif canImport(UIKit)
import UIKit
#endif
import Metal

#if os(macOS)
@MainActor final class LowLevelView: NSView {
  private let device: MTLDevice
  private let queue: MTLCommandQueue

  init(device: MTLDevice, queue: MTLCommandQueue) {
    self.device = device
    self.queue = queue
    super.init(frame: .zero)

    self.wantsLayer = true
    self.metalLayer.configure {
      $0.device = device
      $0.pixelFormat = .bgra8Unorm
      $0.framebufferOnly = true
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

    guard let window else { return }
    self.metalLayer.contentsScale = window.backingScaleFactor
    self.redraw()
  }

  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    self.metalLayer.drawableSize = self.convertToBacking(bounds).size
    self.redraw()
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    self.metalLayer.drawableSize = self.convertToBacking(bounds).size
    self.redraw()
  }
}
#elseif canImport(UIKit)
@MainActor final class LowLevelView: UIView {
  private let device: MTLDevice
  private let queue: MTLCommandQueue

  init(device: MTLDevice, queue: MTLCommandQueue) {
    self.device = device
    self.queue = queue
    super.init(frame: .zero)

    self.metalLayer.configure {
      $0.device = device
      $0.pixelFormat = .bgra8Unorm
      $0.framebufferOnly = true
    }
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  override static var layerClass: AnyClass {
    CAMetalLayer.self
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard let window else { return }
    self.metalLayer.contentsScale = window.screen.nativeScale
    self.redraw()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels.
    let scale = self.metalLayer.contentsScale
    let size = self.bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
    self.metalLayer.drawableSize = size
    self.redraw()
  }
}
#endif

// MARK: - Shared

extension LowLevelView {
  /// Fills the metal layer with a solid color.
  func redraw() {
    // Setup Command Buffer (transient)
    guard self.metalLayer.drawableSize.allSatisfy({ $0 > .zero }),
          let drawable = self.metalLayer.nextDrawable(),
          let commandBuffer = queue.makeCommandBuffer() else { return }
    // Setup the render pass descriptor.
    let renderPass = MTLRenderPassDescriptor().configure {
      $0.colorAttachments[0].configure {
        $0.texture = drawable.texture
        $0.clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1)
        $0.loadAction = .clear
        $0.storeAction = .store
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

private extension LowLevelView {
  var metalLayer: CAMetalLayer {
    self.layer as! CAMetalLayer
  }
}
