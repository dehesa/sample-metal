import UIKit
import MetalKit

class MasterController: UIViewController {
    private var renderer: CowRenderer!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let metalView = self.view as! MTKView
        self.renderer = try! CowRenderer(view: metalView)
        metalView.delegate = self.renderer
    }
}
