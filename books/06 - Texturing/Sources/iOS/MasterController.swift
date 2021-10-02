import UIKit
import MetalKit

final class MasterController: UIViewController {
  private var _renderer: CowRenderer!

  override var prefersStatusBarHidden: Bool {
    true
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let metalView = self.view as! MTKView
    self._renderer = try! CowRenderer(view: metalView)
    metalView.delegate = self._renderer
  }
}
