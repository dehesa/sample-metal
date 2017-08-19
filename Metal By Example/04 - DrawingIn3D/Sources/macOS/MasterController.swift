import Cocoa

class MasterController: NSViewController {
    private var renderer: CubeRenderer!
    private var metalView: MetalView { return self.view as! MetalView }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.renderer = CubeRenderer(withDevice: self.metalView.device)
        self.metalView.delegate = self.renderer
    }
}
