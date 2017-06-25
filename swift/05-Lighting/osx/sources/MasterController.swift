import Cocoa

class MasterController: NSViewController {

    // MARK: Properties
    
    private var renderer: MetalRenderer!
    private var metalView: MetalView { return self.view as! MetalView }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.renderer = MetalRenderer(withDevice: metalView.metalLayer.device!)
        self.metalView.delegate = self.renderer
    }
}

