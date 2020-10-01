import Cocoa
import MetalKit

final class ViewController: NSViewController {
    private let device = MTLCreateSystemDefaultDevice()!
    private var renderer: Renderer!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let metalView = self.view as! MTKView
        metalView.device = self.device
        metalView.colorPixelFormat = .bgra8Unorm
        
        self.renderer = Renderer(device: self.device, view: metalView)
        metalView.delegate = self.renderer
    }
}
