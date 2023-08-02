import SwiftUI

@main struct DrawApp: App {
  var body: some Scene {
    WindowGroup {
      MetalView()
        .ignoresSafeArea()
    }
  }
}
