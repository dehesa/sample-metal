import Cocoa

class MasterController : NSViewController {

    // MARK: Properties
    
    private var renderer : MetalRenderer!
    private var metalView : MetalView { return view as! MetalView }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        renderer = MetalRenderer(withDevice: metalView.metalLayer.device!)
        metalView.delegate = renderer
    }
}

