import SwiftUI

@main struct LightingApp: App {
  var body: some Scene {
    WindowGroup {
      MetalView()
        .ignoresSafeArea()
    }
  }
}
