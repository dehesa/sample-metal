import UIKit
import MetalKit

class MasterController: UIViewController {
    private var renderer: CubeRenderer!
    private var zoomFactor = (base: CGFloat(2.0), pinch: CGFloat(1.0))
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let metalView = self.view as! MTKView
        self.renderer = try! CubeRenderer(view: metalView)
        metalView.delegate = self.renderer
        
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(from:)))
        metalView.addGestureRecognizer(tapGR)
        
        let pinchGR = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(from:)))
        metalView.addGestureRecognizer(pinchGR)
    }
    
    @objc func handleTap(from tapGR: UITapGestureRecognizer) {
        renderer.mipmapMode = renderer.mipmapMode.next
    }
    
    @objc func handlePinch(from pinchGR: UIPinchGestureRecognizer) {
        switch pinchGR.state {
        case .changed:
            zoomFactor.pinch = 1.0 / pinchGR.scale
        case .ended:
            zoomFactor.base *= zoomFactor.pinch
            zoomFactor.pinch = 1.0
        default: break
        }
        
        let constraintZoom = max(1.0, min(100.0, zoomFactor.base*zoomFactor.pinch))
        zoomFactor.pinch = constraintZoom / zoomFactor.base
    }
}
