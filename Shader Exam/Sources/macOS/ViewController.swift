import Cocoa
import MetalKit

final class ViewController: NSViewController {
  private let _device = MTLCreateSystemDefaultDevice()!
  private var _renderer: Renderer!

  override func viewDidLoad() {
    super.viewDidLoad()

    let metalView = self.view as! MTKView
    metalView.device = self._device
    metalView.colorPixelFormat = .bgra8Unorm

    self._renderer = Renderer(device: self._device, view: metalView)
    metalView.delegate = self._renderer
  }
}
