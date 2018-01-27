import UIKit
import MetalKit

class ViewController: UIViewController {
    @IBOutlet weak var metalView: MTKView!
    @IBOutlet weak var edgeLabel: UILabel!
    @IBOutlet weak var insideLabel: UILabel!
    private var pipeline: TessellationPipeline!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.metalView.isPaused = true
        self.metalView.enableSetNeedsDisplay = true
        self.metalView.sampleCount = 4
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.pipeline = TessellationPipeline(view: self.metalView)
        self.metalView.draw()
    }
    
    @IBAction func patchTypeSegmentedControlDidChange(_ sender: UISegmentedControl) {
        self.pipeline.patchType = (sender.selectedSegmentIndex == 0) ? .triangle : .quad
        self.metalView.draw()
    }
    
    @IBAction func wireframeDidChange(_ sender: UISwitch) {
        self.pipeline.wireframe = sender.isOn
        self.metalView.draw()
    }
    
    @IBAction func edgeSliderDidChange(_ sender: UISlider) {
        self.edgeLabel.text = String(format: "%.1f", sender.value)
        self.pipeline.factors.edge = sender.value
        self.metalView.draw()
    }
    
    @IBAction func insideSliderDidChange(_ sender: UISlider) {
        self.insideLabel.text = String(format: "%.1f", sender.value)
        self.pipeline.factors.inside = sender.value
        self.metalView.draw()
    }
}
