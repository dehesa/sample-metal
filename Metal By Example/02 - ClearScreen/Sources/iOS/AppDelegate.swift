import UIKit

extension App {
    @UIApplicationMain
    final class Delegate: UIResponder, UIApplicationDelegate {
        var window: UIWindow?
        
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey:Any]? = nil) -> Bool {
            self.window = UIWindow(frame: UIScreen.main.bounds)
            self.window!.rootViewController = MasterController()
            self.window!.makeKeyAndVisible()
            return true
        }
    }
}
