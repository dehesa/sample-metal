import SwiftUI

#if os(macOS)
struct MetalView: NSViewRepresentable {
  /// Simple passthrough instance exposing the custom `NSView` containing the `CAMetalLayer`.
  func makeNSView(context: Context) -> CAMetalView {
    let renderer = context.coordinator
    return CAMetalView(device: renderer.device, renderer: renderer)
  }

  func updateNSView(_ lowlevelView: CAMetalView, context: Context) {}
}
#elseif canImport(UIKit)
/// Simple passthrough instance exposing the custom `UIView` containing the `CAMetalLayer`.
struct MetalView: UIViewRepresentable {
  func makeUIView(context: Context) -> CAMetalView {
    let renderer = context.coordinator
    return CAMetalView(device: renderer.device, renderer: renderer)
  }

  func updateUIView(_ lowlevelView: CAMetalView, context: Context) {}
}
#endif

extension MetalView {
  @MainActor func makeCoordinator() -> CubeRenderer {
    let device = MTLCreateSystemDefaultDevice()!
    return CubeRenderer(device: device)!
  }
}
