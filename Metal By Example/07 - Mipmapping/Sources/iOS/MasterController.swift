import UIKit
import MetalKit

final class MasterController: UIViewController {
  private var _renderer: CubeRenderer!
  private var _zoomFactor = (base: CGFloat(2.0), pinch: CGFloat(1.0))

  override var prefersStatusBarHidden: Bool {
    true
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let metalView = self.view as! MTKView
    self._renderer = try! CubeRenderer(view: metalView).set {
      $0.mipmapMode = .none
      $0.cameraDistance = zoomFactor.base * zoomFactor.pinch
      metalView.delegate = $0
    }

    let tapGR = UITapGestureRecognizer(target: self, action: #selector(_handleTap(from:)))
    metalView.addGestureRecognizer(tapGR)

    let pinchGR = UIPinchGestureRecognizer(target: self, action: #selector(_handlePinch(from:)))
    metalView.addGestureRecognizer(pinchGR)
  }
}

private extension MasterController {
  @objc func _handleTap(from tapGR: UITapGestureRecognizer) {
    _renderer.mipmapMode = _renderer.mipmapMode.next
  }

  @objc func _handlePinch(from pinchGR: UIPinchGestureRecognizer) {
    switch pinchGR.state {
    case .changed:
      _zoomFactor.pinch = 1.0 / pinchGR.scale
    case .ended:
      _zoomFactor.base *= _zoomFactor.pinch
      _zoomFactor.pinch = 1.0
    default: break
    }

    let constraintZoom = max(1.0, min(100.0, _zoomFactor.base*_zoomFactor.pinch))
    _zoomFactor.pinch = constraintZoom / _zoomFactor.base
    renderer.cameraDistance = self.zoomFactor.base * self.zoomFactor.pinch
  }
}
