import Cocoa
import MetalKit

final class MasterController: NSViewController {
  private var _renderer: TeapotRenderer!

  override func viewDidLoad() {
    super.viewDidLoad()

    let metalView = self.view as! MTKView
    self._renderer = try! TeapotRenderer(view: metalView)
    metalView.delegate = self._renderer
  }
}
