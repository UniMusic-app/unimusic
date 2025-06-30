package app.unimusic

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.session.MediaButtonReceiver
import com.getcapacitor.Bridge
import com.getcapacitor.JSObject

class MediaSessionService : Service() {
    companion object {
        lateinit var bridge: Bridge
        fun isBridgeInitialized() = ::bridge.isInitialized

        const val CHANNEL_ID = "MediaSession"
        const val NOTIFICATION_ID = 420


        const val ACTION_SET_METADATA = "ACTION_SET_METADATA"
        const val ACTION_SET_PLAYBACK_STATE = "ACTION_SET_PLAYBACK_STATE"

        const val TITLE = "TITLE"
        const val ARTIST = "ARTIST"
        const val ALBUM = "ALBUM"
        const val ARTWORK = "ARTWORK"
        const val DURATION = "DURATION"
        const val ELAPSED = "ELAPSED"
        const val PLAYBACK_STATE = "PLAYBACK_STATE"
    }

    private lateinit var mediaSession: MediaSessionCompat

    override fun onCreate() {
        super.onCreate()

        mediaSession = MediaSessionCompat(this, "MediaService").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    notifyJavascript(
                        JSObject().put("action", "play")
                    )
                }

                override fun onPause() {
                    notifyJavascript(
                        JSObject().put("action", "pause")
                    )
                }

                override fun onSeekTo(pos: Long) {
                    notifyJavascript(
                        JSObject()
                            .put("action", "seekTo")
                            .put("position", pos.toDouble() / 1000)
                    )
                }

                override fun onSkipToPrevious() {
                    notifyJavascript(
                        JSObject().put("action", "skipToPrevious")
                    )
                }

                override fun onSkipToNext() {
                    notifyJavascript(
                        JSObject().put("action", "skipToNext")
                    )
                }
            })

            isActive = true
        }

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    fun notifyJavascript(event: JSObject) {
        if (!isBridgeInitialized()) {
            return
        }

        bridge.triggerDocumentJSEvent("mediaSession", event.toString())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let {
            when (it.action) {
                ACTION_SET_METADATA -> {
                    val title = it.getStringExtra(TITLE) ?: ""
                    val artist = it.getStringExtra(ARTIST) ?: ""
                    val album = it.getStringExtra(ALBUM) ?: ""
                    val artwork = it.getStringExtra(ARTWORK) ?: ""
                    val duration = it.getLongExtra(DURATION, 0L)

                    setMetadata(title, artist, album, artwork, duration)
                    updateNotification()
                }

                ACTION_SET_PLAYBACK_STATE -> {
                    val state = it.getStringExtra(PLAYBACK_STATE)?.let { state ->
                        when (state) {
                            "playing" -> PlaybackStateCompat.STATE_PLAYING
                            "paused" -> PlaybackStateCompat.STATE_PAUSED
                            else -> PlaybackStateCompat.STATE_NONE
                        }
                    } ?: PlaybackStateCompat.STATE_NONE
                    val elapsed = it.getLongExtra(ELAPSED, 0L)

                    setPlaybackState(state, elapsed)
                    updateNotification()
                }

                else -> {
                    MediaButtonReceiver.handleIntent(mediaSession, intent)
                }
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onTaskRemoved(rootIntent)
    }
    
    private fun setMetadata(
        title: String?,
        artist: String?,
        album: String?,
        artwork: String?,
        duration: Long,
    ) {
        val artworkBitmap = artwork?.let {
            val uri = Uri.parse(it)
            val bitmap = BitmapFactory.decodeFile(uri.path)
            bitmap
        }

        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, album)
            .putBitmap(MediaMetadataCompat.METADATA_KEY_ART, artworkBitmap)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)
            .build()

        mediaSession.setMetadata(metadata)
    }

    private fun setPlaybackState(state: Int, elapsed: Long) {
        val playbackState = PlaybackStateCompat.Builder()
            .setState(state, elapsed, 1f)
            .setActions(
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                        PlaybackStateCompat.ACTION_SEEK_TO
            )
            .build()

        mediaSession.setPlaybackState(playbackState)
    }

    private fun updateNotification() {
        val notification = buildNotification()
        val notifManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        notifManager.notify(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(): Notification {
        val context = this

        // Intent to launch the app
        val activityIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = PendingIntent.getActivity(
            this, 0, activityIntent, PendingIntent.FLAG_IMMUTABLE
        )

        val controller = mediaSession.controller
        val description = controller?.metadata?.description

        val builder = NotificationCompat.Builder(context, CHANNEL_ID).apply {
            setContentTitle(description?.title ?: "UniMusic.app")
            setContentText(description?.subtitle ?: "Music player")

            setSmallIcon(android.R.drawable.ic_media_play)

            // NOTE:
            addAction(
                android.R.drawable.ic_media_previous,
                "Skip to previous",
                MediaButtonReceiver.buildMediaButtonPendingIntent(
                    context,
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS,
                )
            )

            val isPlaying = controller.playbackState?.state == PlaybackStateCompat.STATE_PLAYING
            addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "Pause" else "Play",
                MediaButtonReceiver.buildMediaButtonPendingIntent(
                    context,
                    PlaybackStateCompat.ACTION_PLAY_PAUSE,
                )
            )

            addAction(
                android.R.drawable.ic_media_next,
                "Skip to next",
                MediaButtonReceiver.buildMediaButtonPendingIntent(
                    context,
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT,
                )
            )

            // Launch the app when clicking notification
            setContentIntent(contentIntent)

            setWhen(0)
            setOngoing(true)
            setOnlyAlertOnce(true)
            setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(controller.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )

            setAllowSystemGeneratedContextualActions(false)
        }

        val notification = builder.build()
        notification.flags =
            NotificationCompat.FLAG_ONGOING_EVENT or NotificationCompat.FLAG_NO_CLEAR
        return notification
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Media Playback",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
