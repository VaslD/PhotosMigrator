import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var observers: [NSObjectProtocol] = []

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func applicationWillTerminate(_: UIApplication) {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
