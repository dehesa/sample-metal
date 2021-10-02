import UIKit

final class MasterController: UIViewController {
  private var _renderer: CubeRenderer! = nil
  private var _metalView: MetalView { self.view as! MetalView }

  override var prefersStatusBarHidden: Bool { true }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let device = MTLCreateSystemDefaultDevice() else { fatalError() }
    let metalView = MetalView(frame: UIScreen.main.bounds, device: device)
    self._renderer = CubeRenderer(withDevice: device)
    metalView.delegate = self._renderer
    self.view = metalView
  }
}
