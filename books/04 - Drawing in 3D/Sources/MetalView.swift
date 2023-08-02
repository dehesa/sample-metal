import SwiftUI

#if os(macOS)
struct MetalView: NSViewRepresentable {
  @State private var renderer = CubeRenderer(device: MTLCreateSystemDefaultDevice()!)

  func makeNSView(context: Context) -> LowLevelView {
    LowLevelView(device: renderer!.device, renderer: renderer)
  }

  func updateNSView(_ lowlevelView: LowLevelView, context: Context) {}
}
#elseif canImport(UIKit)
struct MetalView: UIViewRepresentable {
  @State private var renderer = CubeRenderer(device: MTLCreateSystemDefaultDevice()!)

  func makeUIView(context: Context) -> LowLevelView {
    LowLevelView(device: renderer!.device, renderer: renderer)
  }

  func updateUIView(_ lowlevelView: LowLevelView, context: Context) {}
}
#endif
