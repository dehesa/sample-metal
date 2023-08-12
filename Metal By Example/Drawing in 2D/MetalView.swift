import SwiftUI

#if os(macOS)
/// Simple passthrough instance exposing the custom `NSView` containing the `CAMetalLayer`.
struct MetalView: NSViewRepresentable {
  func makeNSView(context: Context) -> CAMetalView {
    let device = MTLCreateSystemDefaultDevice()!
    let queue = device.makeCommandQueue()!.configure { $0.label = .identifier("queue") }
    return CAMetalView(device: device, queue: queue)
  }

  func updateNSView(_ lowlevelView: CAMetalView, context: Context) {}
}
#elseif canImport(UIKit)
/// Simple passthrough instance exposing the custom `UIView` containing the `CAMetalLayer`.
struct MetalView: UIViewRepresentable {
  func makeUIView(context: Context) -> CAMetalView {
    let device = MTLCreateSystemDefaultDevice()!
    let queue = device.makeCommandQueue()!.configure { $0.label = .identifier("queue") }
    return CAMetalView(device: device, queue: queue)
  }

  func updateUIView(_ lowlevelView: CAMetalView, context: Context) {}
}
#endif
