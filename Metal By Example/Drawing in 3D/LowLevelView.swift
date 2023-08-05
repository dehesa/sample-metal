#if os(macOS)
import Cocoa
#elseif canImport(UIKit)
import UIKit
#endif
import Metal

#if os(macOS)
@MainActor final class LowLevelView: NSView {
  private let metalState: MetalState

  init(device: MTLDevice, renderer: Renderer?) {
    self.metalState = MetalState(device: device, renderer: renderer)!
    super.init(frame: .zero)

    self.wantsLayer = true
    self.metalState.layer = (layer as? CAMetalLayer)?.configure {
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
    self.metalState.timer = .none
    super.viewDidMoveToWindow()

    guard let window else { return }
    self.metalState.layer!.contentsScale = window.backingScaleFactor
    self.metalState.timer = FrameTimer { [unowned(unsafe) self] (now, out) in
      guard let renderer = self.metalState.renderer,
            let layer = metalState.layer else { return }
      renderer.draw(layer: layer, time: (now, out))
    }
  }
}
#elseif canImport(UIKit)
@MainActor final class LowLevelView: UIView {
  private let metalState: MetalState

  init(device: MTLDevice, renderer: Renderer?) {
    self.metalState = MetalState(device: device, renderer: renderer)!
    super.init(frame: .zero)

    self.metalState.layer = (layer as? CAMetalLayer)?.configure {
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
    self.metalState.timer = .none
    super.didMoveToWindow()

    guard let window else { return }
    self.metalState.layer!.contentsScale = window.screen.nativeScale
    self.metalState.timer = FrameTimer { [unowned(unsafe) self] (now, out) in
      guard let renderer = self.metalState.renderer,
            let layer = metalState.layer else { return }
      renderer.draw(layer: layer, time: (now, out))
    }
  }
}
#endif

// MARK: -

private extension LowLevelView {
  final class MetalState {
    let device: MTLDevice
    weak var layer: CAMetalLayer?
    weak var renderer: Renderer?
    var timer: FrameTimer?

    init?(device: MTLDevice, renderer: Renderer?) {
      self.device = device
      self.renderer = renderer
    }
  }
}
