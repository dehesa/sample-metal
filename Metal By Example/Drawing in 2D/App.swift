import SwiftUI

@main struct DrawingApp: App {
  var body: some Scene {
    WindowGroup {
      MetalView()
        .ignoresSafeArea()
    }
  }
}
