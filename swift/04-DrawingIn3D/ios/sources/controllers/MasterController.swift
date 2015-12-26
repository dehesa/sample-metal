import UIKit

class MasterController : UIViewController {
    
    // MARK: Properties
    
    private let renderer = MetalRenderer()
    
    // MARK: Functionality

    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        (self.view as! MetalView).delegate = self.renderer
    }
}

