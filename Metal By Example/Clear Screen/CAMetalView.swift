#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Metal

#if os(macOS)
/// Custom `NSView` holding the `CAMetalLayer` where the drawing will end up.
@MainActor final class CAMetalView: NSView {
  /// Representation of the system GPU.
  private let device: any MTLDevice
  /// Serial queue of buffer commands.
  private let queue: any MTLCommandQueue

  init(device: any MTLDevice, queue: any MTLCommandQueue) {
    self.device = device
    self.queue = queue
    super.init(frame: .zero)
    // A special layer is created to draw with Metal
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
    self.draw()
  }

  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    self.metalLayer.drawableSize = self.convertToBacking(bounds).size
    self.draw()
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    self.metalLayer.drawableSize = self.convertToBacking(bounds).size
    self.draw()
  }
}
#elseif canImport(UIKit)
/// Custom `UIView` holding the `CAMetalLayer` where the drawing will end up.
@MainActor final class CAMetalView: UIView {
  /// Representation of the system GPU.
  private let device: any MTLDevice
  /// Serial queue of buffer commands.
  private let queue: any MTLCommandQueue

  init(device: any MTLDevice, queue: any MTLCommandQueue) {
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
    self.draw()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels.
    let scale = self.metalLayer.contentsScale
    let size = self.bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
    self.metalLayer.drawableSize = size
    self.draw()
  }
}
#endif

// MARK: - Shared

private extension CAMetalView {
  /// Fills the metal layer with a solid color.
  func draw() {
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

  var metalLayer: CAMetalLayer {
    self.layer as! CAMetalLayer
  }
}
