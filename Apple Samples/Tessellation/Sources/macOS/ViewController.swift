import Cocoa
import MetalKit

final class ViewController: NSViewController {
  @IBOutlet weak var metalView: MTKView!
  @IBOutlet weak var edgeLabel: NSTextField!
  @IBOutlet weak var insideLabel: NSTextField!
  private var _pipeline: TessellationPipeline!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.metalView.isPaused = true
    self.metalView.enableSetNeedsDisplay = true
    self.metalView.sampleCount = 4
  }

  override func viewDidAppear() {
    super.viewDidAppear()

    self._pipeline = TessellationPipeline(view: self.metalView)
  }
}

private extension ViewController {
  @IBAction func patchTypeSegmentedControlDidChange(_ sender: NSSegmentedControl) {
    self._pipeline.patchType = (sender.selectedSegment == 0) ? .triangle : .quad
    self.metalView.draw()
  }

  @IBAction func wireframeDidChange(_ sender: NSButton) {
    self._pipeline.wireframe = (sender.state == .on)
    self.metalView.draw()
  }

  @IBAction func edgeSliderDidChange(_ sender: NSSlider) {
    self.edgeLabel.stringValue = String(format: "%.1f", sender.floatValue)
    self._pipeline.factors.edge = sender.floatValue
    self.metalView.draw()
  }

  @IBAction func insideSliderDidChange(_ sender: NSSlider) {
    self.insideLabel.stringValue = String(format: "%.1f", sender.floatValue)
    self._pipeline.factors.inside = sender.floatValue
    self.metalView.draw()
  }
}
