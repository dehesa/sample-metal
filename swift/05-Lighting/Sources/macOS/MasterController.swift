import Cocoa
import MetalKit

class MasterController: NSViewController {
    private var renderer: TeapotRenderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let metalView = self.view as! MTKView
        self.renderer = try! TeapotRenderer(view: metalView)
        metalView.delegate = self.renderer
    }
}
