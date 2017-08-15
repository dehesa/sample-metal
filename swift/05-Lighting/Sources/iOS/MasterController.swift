import UIKit
import MetalKit

class MasterController: UIViewController {
    private var renderer: TeapotRenderer!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let metalView = self.view as! MTKView
        self.renderer = try! TeapotRenderer(view: metalView)
        metalView.delegate = self.renderer
    }
}
