import SwiftUI

@main struct DrawApp: App {
  @State var device: MTLDevice = MTLCreateSystemDefaultDevice()!

  var body: some Scene {
    WindowGroup {
      MetalView(device: self.device)
        .ignoresSafeArea()
    }
  }
}
