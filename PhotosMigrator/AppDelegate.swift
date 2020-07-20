import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let manager = FileManager.default
        if let root = try? manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let readMe = root.appendingPathComponent("ReadMe.md")
            manager.createFile(atPath: readMe.path, contents: nil, attributes: nil)
        }

        return true
    }
}
