import SwiftUI
import MetalKit

#if os(macOS)
struct MetalView: NSViewRepresentable {
  @State private var renderer: Renderer?

  @MainActor init(device: MTLDevice) {
    self._renderer = State(initialValue: TeapotRenderer(device: device))
  }

  func makeNSView(context: Context) -> MTKView {
    let renderer = self.renderer!
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
  @State private var renderer: Renderer?

  @MainActor init(device: MTLDevice) {
    self._renderer = State(initialValue: TeapotRenderer(device: device))
  }

  func makeUIView(context: Context) -> MTKView {
    let renderer = self.renderer!
    return MTKView(frame: 400, device: renderer.device).configure {
      $0.clearColor = MTLClearColorMake(0, 0, 0, 1)
      $0.colorPixelFormat = .bgra8Unorm
      $0.depthStencilPixelFormat = .depth32Float
      $0.delegate = renderer
    }
  }

  func updateUIView(_ lowlevelView: MTKView, context: Context) {}
}
#endif
