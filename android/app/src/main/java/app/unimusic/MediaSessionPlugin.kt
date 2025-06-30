package app.unimusic

import android.content.Intent
import androidx.core.content.ContextCompat
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin

@Suppress("unused")
@CapacitorPlugin(name = "MediaSession")
class MediaSessionPlugin : Plugin() {
    private val serviceClass = MediaSessionService::class.java

    @PluginMethod
    fun initialize(call: PluginCall) {
        MediaSessionService.bridge = bridge
        call.resolve()
    }

    @PluginMethod
    fun setPlaybackState(call: PluginCall) {
        val state = call.getString("state") ?: run {
            call.reject("You need to provide 'state' option")
            return
        }

        val elapsed = call.getDouble("elapsed") ?: run {
            call.reject("You need to provide 'elapsed' option")
            return
        }

        val intent = Intent(context, serviceClass).apply {
            action = MediaSessionService.ACTION_SET_PLAYBACK_STATE
            putExtra(MediaSessionService.ELAPSED, (elapsed * 1000.0).toLong())
            putExtra(MediaSessionService.PLAYBACK_STATE, state)
        }

        ContextCompat.startForegroundService(context, intent)

        call.resolve()
    }

    @PluginMethod
    fun setMetadata(call: PluginCall) {
        val title = call.getString("title")
        val artist = call.getString("artist")
        val album = call.getString("album")
        val artwork = call.getString("artwork")
        val duration = call.getDouble("duration")

        val intent = Intent(context, serviceClass).apply {
            action = MediaSessionService.ACTION_SET_METADATA
            putExtra(MediaSessionService.TITLE, title)
            putExtra(MediaSessionService.ARTIST, artist)
            putExtra(MediaSessionService.ALBUM, album)
            putExtra(MediaSessionService.ARTWORK, artwork)
            putExtra(MediaSessionService.DURATION, duration?.let { (it * 1000.0).toLong() })
        }

        ContextCompat.startForegroundService(context, intent)

        call.resolve()
    }
}

