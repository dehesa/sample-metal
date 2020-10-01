import UIKit

final class MasterController: UIViewController {
    private var renderer: CubeRenderer! = nil
    private var metalView: MetalView { self.view as! MetalView }
    override var prefersStatusBarHidden: Bool { true }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError() }
        let metalView = MetalView(frame: UIScreen.main.bounds, device: device)
        self.renderer = CubeRenderer(withDevice: device)
        metalView.delegate = self.renderer
        self.view = metalView
    }
}
