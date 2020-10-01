import UIKit

final class MasterController: UIViewController {
    override var prefersStatusBarHidden: Bool { true }
    
    override func viewDidLoad() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { fatalError() }
        self.view = MetalView(frame: UIScreen.main.bounds, device: device, queue: queue)
    }
}
