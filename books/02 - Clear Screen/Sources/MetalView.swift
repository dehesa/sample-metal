import SwiftUI

#if os(macOS)
struct MetalView: NSViewRepresentable {
  func makeNSView(context: Context) -> LowLevelView {
    let device = MTLCreateSystemDefaultDevice()!
    let queue = device.makeCommandQueue()!.configure { $0.label = Bundle.main.bundleIdentifier! + ".queue" }
    return LowLevelView(device: device, queue: queue)
  }

  func updateNSView(_ lowlevelView: LowLevelView, context: Context) {
    lowlevelView.redraw()
  }
}
#elseif canImport(UIKit)
struct MetalView: UIViewRepresentable {
  func makeUIView(context: Context) -> LowLevelView {
    let device = MTLCreateSystemDefaultDevice()!
    let queue = device.makeCommandQueue()!.configure { $0.label = Bundle.main.bundleIdentifier! + ".queue" }
    return LowLevelView(device: device, queue: queue)
  }

  func updateUIView(_ lowlevelView: LowLevelView, context: Context) {
    lowlevelView.redraw()
  }
}
#endif
