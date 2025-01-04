import UIKit
import Capacitor
import MusicKit

class MusicPlayerViewController: CAPBridgeViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(MusicKitAuthorizationPlugin())
    }
}
