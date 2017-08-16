import Cocoa
import MetalKit

class MasterController: NSViewController {
    private var renderer: CowRenderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let metalView = self.view as! MTKView
        self.renderer = try! CowRenderer(view: metalView)
        metalView.delegate = self.renderer
    }
}
