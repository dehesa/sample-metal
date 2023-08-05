import SwiftUI

#if os(macOS)
struct MetalView: NSViewRepresentable {
  func makeNSView(context: Context) -> LowLevelView {
    let renderer = context.coordinator
    return LowLevelView(device: renderer.device, renderer: renderer)
  }

  func updateNSView(_ lowlevelView: LowLevelView, context: Context) {}
}
#elseif canImport(UIKit)
struct MetalView: UIViewRepresentable {
  func makeUIView(context: Context) -> LowLevelView {
    let renderer = context.coordinator
    return LowLevelView(device: renderer.device, renderer: renderer)
  }

  func updateUIView(_ lowlevelView: LowLevelView, context: Context) {}
}
#endif

extension MetalView {
  @MainActor func makeCoordinator() -> CubeRenderer {
    let device = MTLCreateSystemDefaultDevice()!
    return CubeRenderer(device: device)!
  }
}
