import Capacitor
import Network

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // NOTE: Without this the application crashes on iOS 26
        nw_tls_create_options()
        return true
    }
}
