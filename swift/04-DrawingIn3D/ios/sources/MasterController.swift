import UIKit

class MasterController : UIViewController {
    
    // MARK: Properties
    
    private var renderer : MetalRenderer!
    private var metalView : MetalView { return self.view as! MetalView }
    
    // MARK: Functionality

    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.renderer = MetalRenderer(withDevice: metalView.metalLayer.device!)
        self.metalView.delegate = self.renderer
    }
}
