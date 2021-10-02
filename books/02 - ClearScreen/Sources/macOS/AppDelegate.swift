import Cocoa

extension App {
  /// The delegate for this application. It receives the app events and forwards them to the window controller or SwiftUI.
  final class Delegate: NSObject {
    /// The main application window.
    private let _window: NSWindow

    override init() {
      let size = (default: NSSize(width: 900, height: 600),
                  minimum: NSSize(width: 300, height: 300))
      let mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
      self._window = NSWindow(contentRect: .init(origin: .zero, size: size.default), styleMask: mask, backing: .buffered, defer: false).set {
        $0.minSize = size.minimum
        $0.appearance = NSAppearance(named: .darkAqua)
        $0.title = App.name + " - Clear Screen"
        $0.isReleasedWhenClosed = false
      }
      super.init()
      self._window.delegate = self
    }
  }
}

extension App.Delegate: NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = NSMenu().set {
      $0.addItem(NSMenuItem(title: App.name, action: nil, keyEquivalent: "").set {
        $0.submenu = NSMenu(title: App.name).set {
          $0.addItem(withTitle: "Hide window", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
          $0.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
          $0.addItem(.separator())
          $0.addItem(withTitle: "Quit sample code", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        }
      })
    }

    guard let device = MTLCreateSystemDefaultDevice(),
          let queue = device.makeCommandQueue() else { fatalError() }
    self._window.contentView = MetalView(frame: self._window.contentLayoutRect, device: device, queue: queue)
    self._window.center()
    self._window.makeKeyAndOrderFront(self)

    NSApp.activate(ignoringOtherApps: true)
  }
}

extension App.Delegate: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    NSApp.terminate(self)
  }
}
