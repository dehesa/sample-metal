import UIKit

class MasterController: UIViewController {
    private var renderer: MetalRenderer!
    private var metalView: MetalView {
        return self.view as! MetalView
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.renderer = MetalRenderer(withDevice: self.metalView.device)
        self.metalView.delegate = self.renderer
    }
}
