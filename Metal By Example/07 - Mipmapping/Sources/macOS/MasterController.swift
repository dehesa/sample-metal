import Cocoa
import MetalKit

class MasterController: NSViewController {
    private var renderer: CubeRenderer!
    private var zoomFactor = (base: CGFloat(2.0), pinch: CGFloat(1.0))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let metalView = self.view as! MTKView
        self.renderer = try! CubeRenderer(view: metalView).set { [unowned self] in
            $0.mipmapMode = .none
            $0.cameraDistance = Float(self.zoomFactor.base * self.zoomFactor.pinch)
            metalView.delegate = $0
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        renderer.mipmapMode = renderer.mipmapMode.next
    }
    
    override func scrollWheel(with event: NSEvent) {
        print(event)
    }
}
