import Cocoa

class MasterController: NSViewController {
    private var renderer: MetalRenderer!
    private var metalView: MetalView { return self.view as! MetalView }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.renderer = MetalRenderer(withDevice: self.metalView.device)
        self.metalView.delegate = self.renderer
    }
}
