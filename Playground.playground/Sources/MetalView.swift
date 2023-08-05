#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Metal

#if os(macOS)
public final class MetalView: NSView {
  private let device: MTLDevice
  private let queue: MTLCommandQueue
  private let onDraw: DrawClosure
  private var timer: FrameTimer?

  public init(device: MTLDevice, queue: MTLCommandQueue, draw: @escaping DrawClosure) {
    self.device = device
    self.queue = queue
    self.onDraw = draw
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

  override public func makeBackingLayer() -> CALayer {
    CAMetalLayer()
  }

  override public func viewDidMoveToWindow() {
    self.timer = .none
    super.viewDidMoveToWindow()

    guard let window else { return }
    self.metalLayer.contentsScale = window.backingScaleFactor
    self.timer = FrameTimer { [unowned(unsafe) self] in self.redraw(now: $0, frame: $1) }
  }

  override public func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    self.metalLayer.drawableSize = self.convertToBacking(self.bounds).size
  }

  override public func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    self.metalLayer.drawableSize = self.convertToBacking(self.bounds).size
  }
}
#elseif canImport(UIKit)
public final class MetalView: UIView {
  private let device: MTLDevice
  private let queue: MTLCommandQueue
  private let onDraw: DrawClosure
  private var timer: FrameTimer?

  public init(device: MTLDevice, queue: MTLCommandQueue, draw: @escaping DrawClosure) {
    self.device = device
    self.queue = queue
    self.onDraw = draw
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

  override public static var layerClass: AnyClass {
    CAMetalLayer.self
  }

  override public func didMoveToWindow() {
    self.timer = .none
    super.didMoveToWindow()

    guard let window else { return }
    self.metalLayer.contentsScale = window.screen.nativeScale
    self.timer = FrameTimer { [unowned(unsafe) self] in self.redraw(now: $0, frame: $1) }
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    let scale = self.metalLayer.contentsScale
    let size = self.bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
    self.metalLayer.drawableSize = size
  }
}
#endif

// MARK: - Shared

public extension MetalView {
  typealias DrawClosure = (_ layer: CAMetalLayer, _ now: Double, _ output: Double) -> Void
  /// Fills the metal layer with a solid color.
  func redraw(now: Double, frame: Double) {
    guard self.metalLayer.drawableSize.allSatisfy({ $0 > .zero }) else { return }
    self.onDraw(self.metalLayer, now, frame)
  }
}

private extension MetalView {
  var metalLayer: CAMetalLayer {
    self.layer as! CAMetalLayer
  }
}
