import Cocoa
import MetalKit

class MasterController: NSViewController {
    private var renderer: CubeRenderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let metalView = self.view as! MTKView
        self.renderer = try! CubeRenderer(view: metalView)
        metalView.delegate = self.renderer
    }
}
