package app.unimusic

import android.os.Bundle
import app.unimusic.sync.UniMusicSync
import com.getcapacitor.BridgeActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

class MainActivity : BridgeActivity() {
    private val appJob = SupervisorJob()
    private val appScope = CoroutineScope(Dispatchers.IO + appJob)

    lateinit var uniMusicSync: UniMusicSync
        private set

    override fun onCreate(savedInstanceState: Bundle?) {
        appScope.launch {
            val sync = UniMusicSync.create(applicationContext.cacheDir.path);
            val author = sync.getAuthor();
            uniMusicSync = sync
            println("IROH Author: $author")
        }

        registerPlugin(MusicKitAuthorizationPlugin::class.java)
        registerPlugin(LocalMusicPlugin::class.java)

        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        super.onDestroy()
        appJob.cancelChildren()
        if (::uniMusicSync.isInitialized) {
            runBlocking {
                uniMusicSync.shutdown()
            }
            uniMusicSync.close()
        }
    }

    override fun onStart() {
        if (::uniMusicSync.isInitialized) appScope.launch {
            val author = uniMusicSync?.getAuthor();
            println("IROH Author: $author")
        }

        val bridge = super.getBridge()
        val webView = bridge.webView
        webView.webViewClient = CleanWebViewClient(bridge)
        super.onStart()
    }
}
