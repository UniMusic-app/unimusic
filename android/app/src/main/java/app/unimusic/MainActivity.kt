package app.unimusic

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup.MarginLayoutParams
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.getcapacitor.BridgeActivity
import java.lang.String
import kotlin.math.roundToInt


class MainActivity : BridgeActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        registerPlugin(MusicKitAuthorizationPlugin::class.java)
        registerPlugin(LocalMusicPlugin::class.java)
        registerPlugin(DirectoryPickerPlugin::class.java)
        registerPlugin(UniMusicSyncPlugin::class.java)
        registerPlugin(StorageAccessFrameworkPlugin::class.java)
        registerPlugin(MediaSessionPlugin::class.java)

        super.onCreate(savedInstanceState)
    }

    override fun onStart() {
        val bridge = super.getBridge()
        val webView = bridge.webView
        webView.webViewClient = CleanWebViewClient(bridge)
        super.onStart()
    }
}
