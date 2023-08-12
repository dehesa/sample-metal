#if os(macOS)
import Cocoa
#elseif canImport(UIKit)
import UIKit
#endif
import Metal

#if os(macOS)
@MainActor final class CAMetalView: NSView {
  private let metalState: MetalState

  init(device: any MTLDevice, renderer: (any Renderer)?) {
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
@MainActor final class CAMetalView: UIView {
  private let metalState: MetalState

  init(device: any MTLDevice, renderer: (any Renderer)?) {
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

private extension CAMetalView {
  final class MetalState {
    let device: any MTLDevice
    weak var layer: CAMetalLayer?
    weak var renderer: (any Renderer)?
    var timer: FrameTimer?

    init?(device: any MTLDevice, renderer: (any Renderer)?) {
      self.device = device
      self.renderer = renderer
    }
  }
}
