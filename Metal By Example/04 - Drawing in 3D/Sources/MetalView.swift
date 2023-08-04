import SwiftUI

#if os(macOS)
struct MetalView: NSViewRepresentable {
  @State private var renderer: Renderer?

  init(device: MTLDevice) {
    self._renderer = State(initialValue: CubeRenderer(device: device))
  }

  func makeNSView(context: Context) -> LowLevelView {
    LowLevelView(device: renderer!.device, renderer: renderer)
  }

  func updateNSView(_ lowlevelView: LowLevelView, context: Context) {}
}
#elseif canImport(UIKit)
struct MetalView: UIViewRepresentable {
  @State private var renderer: Renderer?

  init(device: MTLDevice) {
    self._renderer = State(initialValue: CubeRenderer(device: device))
  }

  func makeUIView(context: Context) -> LowLevelView {
    LowLevelView(device: renderer!.device, renderer: renderer)
  }

  func updateUIView(_ lowlevelView: LowLevelView, context: Context) {}
}
#endif
