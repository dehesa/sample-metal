import Cocoa
import MetalKit

final class MasterController: NSViewController {
  private var _renderer: CubeRenderer!
  private var _zoomFactor: (base: CGFloat, pinch: CGFloat) = (2, 1)

  override func viewDidLoad() {
    super.viewDidLoad()

    let metalView = self.view as! MTKView
    self._renderer = try! CubeRenderer(view: metalView).set { [unowned self] in
      $0.mipmapMode = .none
      $0.cameraDistance = Float(self._zoomFactor.base * self._zoomFactor.pinch)
      metalView.delegate = $0
    }
  }

  override func mouseDown(with event: NSEvent) {
    _renderer.mipmapMode = _renderer.mipmapMode.next
  }

  override func scrollWheel(with event: NSEvent) {
    print(event)
  }
}
