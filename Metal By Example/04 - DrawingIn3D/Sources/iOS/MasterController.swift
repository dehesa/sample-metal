import UIKit

class MasterController: UIViewController {
    private var renderer: CubeRenderer!
    private var metalView: MetalView {
        return self.view as! MetalView
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.renderer = CubeRenderer(withDevice: self.metalView.device)
        self.metalView.delegate = self.renderer
    }
}
