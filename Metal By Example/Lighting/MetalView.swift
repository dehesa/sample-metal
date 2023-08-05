import SwiftUI
import MetalKit

#if os(macOS)
struct MetalView: NSViewRepresentable {
  func makeNSView(context: Context) -> MTKView {
    let renderer = context.coordinator
    return MTKView(frame: .zero, device: renderer.device).configure {
      $0.clearColor = MTLClearColorMake(0, 0, 0, 1)
      $0.colorPixelFormat = .bgra8Unorm
      $0.depthStencilPixelFormat = .depth32Float
      $0.delegate = renderer
    }
  }

  func updateNSView(_ lowlevelView: MTKView, context: Context) {}
}
#elseif canImport(UIKit)
struct MetalView: UIViewRepresentable {
  func makeUIView(context: Context) -> MTKView {
    let renderer = context.coordinator
    return MTKView(frame: .zero, device: renderer.device).configure {
      $0.clearColor = MTLClearColorMake(0, 0, 0, 1)
      $0.colorPixelFormat = .bgra8Unorm
      $0.depthStencilPixelFormat = .depth32Float
      $0.delegate = renderer
    }
  }

  func updateUIView(_ lowlevelView: MTKView, context: Context) {}
}
#endif

extension MetalView {
  @MainActor func makeCoordinator() -> TeapotRenderer {
    let device = MTLCreateSystemDefaultDevice()!
    return TeapotRenderer(device: device)!
  }
}
