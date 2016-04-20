import UIKit

class MasterController : UIViewController {
    
    // MARK: Properties
    
    private var renderer : MetalRenderer!
    private var metalView : MetalView { return view as! MetalView }
    
    // MARK: Functionality

    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        renderer = MetalRenderer(withDevice: metalView.metalLayer.device!)
        metalView.delegate = renderer
    }
}
