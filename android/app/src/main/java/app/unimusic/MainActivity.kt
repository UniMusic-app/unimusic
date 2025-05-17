package app.unimusic

import android.os.Bundle
import com.getcapacitor.BridgeActivity

class MainActivity : BridgeActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        registerPlugin(MusicKitAuthorizationPlugin::class.java)
        registerPlugin(LocalMusicPlugin::class.java)
        super.onCreate(savedInstanceState)
    }

    override fun onStart() {
        val bridge = super.getBridge()
        val webView = bridge.webView
        webView.webViewClient = CleanWebViewClient(bridge)
        super.onStart()
    }
}
