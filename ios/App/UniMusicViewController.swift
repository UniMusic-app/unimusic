import Capacitor
import MusicKit
import UIKit
import UniMusicSync

class UniMusicViewController: CAPBridgeViewController {
    private var keepWebViewAlive: Timer?

    deinit {
        keepWebViewAlive?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Run Javascript code every 5 seconds to keep WebView alive.
        // This is necessary, since in case user does not interact with WebView in ~20-30s iOS will simply kill it
        // and we obviously need javascript to interact with the app
        keepWebViewAlive = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            self.webView?.evaluateJavaScript("!!document.body")
        }
    }

    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(MusicKitAuthorizationPlugin())
        bridge?.registerPluginInstance(UniMusicSyncPlugin())
    }
}
