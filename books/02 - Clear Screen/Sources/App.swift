import SwiftUI

@main struct ClearScreenApp: App {
  var body: some Scene {
    WindowGroup {
      MetalView()
        .ignoresSafeArea()
    }
  }
}
