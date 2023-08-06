import SwiftUI
import MetalKit

#if os(macOS)
struct MetalView: NSViewRepresentable {
  let exercise: Exercise

  func makeNSView(context: Context) -> MTKView {
    let renderer = context.coordinator
    return MTKView(frame: .zero, device: renderer.device).configure {
      $0.clearColor = MTLClearColorMake(0, 0, 0, 1)
      $0.colorPixelFormat = .rgba8Unorm
      $0.isPaused = true
      $0.enableSetNeedsDisplay = true
      $0.delegate = renderer
    }
  }

  func updateNSView(_ view: MTKView, context: Context) {
    context.coordinator.setExercise(self.exercise, view: view)
  }
}
#elseif canImport(UIKit)
struct MetalView: UIViewRepresentable {
  let exercise: Exercise

  func makeUIView(context: Context) -> MTKView {
    let renderer = context.coordinator
    return MTKView(frame: .zero, device: renderer.device).configure {
      $0.clearColor = MTLClearColorMake(0, 0, 0, 1)
      $0.colorPixelFormat = .rgba8Unorm
      $0.isPaused = true
      $0.enableSetNeedsDisplay = true
      $0.delegate = renderer
    }
  }

  func updateUIView(_ view: MTKView, context: Context) {
    context.coordinator.setExercise(self.exercise, view: view)
  }
}
#endif

extension MetalView {
  @MainActor func makeCoordinator() -> PikachuRenderer {
    let device = MTLCreateSystemDefaultDevice()!
    return PikachuRenderer(device: device, exercise: self.exercise)
  }
}
