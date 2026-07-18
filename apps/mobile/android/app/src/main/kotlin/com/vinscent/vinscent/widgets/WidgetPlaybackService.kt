package com.vinscent.vinscent.widgets

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import com.vinscent.vinscent.MainActivity
import com.vinscent.vinscent.R
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File

class WidgetPlaybackService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var preparing = false
    private var bounceRaised = false
    private lateinit var audioManager: AudioManager
    private var audioFocusRequest: AudioFocusRequest? = null
    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener {
        onAudioFocusChanged(it)
    }

    private val bounce = object : Runnable {
        override fun run() {
            bounceRaised = !bounceRaised
            CharacterWidgetProvider.updateAll(this@WidgetPlaybackService, bounceRaised)
            handler.postDelayed(this, BOUNCE_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_TOGGLE) return START_NOT_STICKY
        if (preparing || player?.isPlaying == true) {
            stopPlayback()
        } else {
            startPlayback()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        releasePlayback(updateWidget = true)
        super.onDestroy()
    }

    private fun startPlayback() {
        val data = HomeWidgetPlugin.getData(this)
        val audioPath = data.getString(WidgetStorageKeys.RECORDING_AUDIO_PATH, null)
        if (audioPath.isNullOrBlank() || !File(audioPath).isFile) {
            stopSelf()
            return
        }

        try {
            startForeground(NOTIFICATION_ID, buildNotification())
            preparing = true
            val nextPlayer = MediaPlayer()
            player = nextPlayer
            nextPlayer.apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build(),
                )
                setDataSource(audioPath)
                setOnPreparedListener { preparedPlayer ->
                    preparing = false
                    if (!requestAudioFocus()) {
                        stopPlayback()
                        return@setOnPreparedListener
                    }
                    preparedPlayer.start()
                    data.edit().putBoolean(WidgetStorageKeys.CHARACTER_PLAYING, true).apply()
                    handler.removeCallbacks(bounce)
                    handler.post(bounce)
                }
                setOnCompletionListener { stopPlayback() }
                setOnErrorListener { _, _, _ ->
                    stopPlayback()
                    true
                }
                prepareAsync()
            }
        } catch (_: Exception) {
            stopPlayback()
        }
    }

    private fun stopPlayback() {
        releasePlayback(updateWidget = true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun releasePlayback(updateWidget: Boolean) {
        preparing = false
        handler.removeCallbacks(bounce)
        player?.runCatching {
            if (isPlaying) stop()
        }
        player?.release()
        player = null
        abandonAudioFocus()
        HomeWidgetPlugin.getData(this)
            .edit()
            .putBoolean(WidgetStorageKeys.CHARACTER_PLAYING, false)
            .apply()
        if (updateWidget) CharacterWidgetProvider.updateAll(this, false)
    }

    private fun requestAudioFocus(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build(),
                )
                .setOnAudioFocusChangeListener(audioFocusChangeListener)
                .build()
            audioFocusRequest = request
            audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let(audioManager::abandonAudioFocusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(audioFocusChangeListener)
        }
        audioFocusRequest = null
    }

    private fun onAudioFocusChanged(change: Int) {
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> stopPlayback()
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> player?.setVolume(0.25f, 0.25f)
            AudioManager.AUDIOFOCUS_GAIN -> player?.setVolume(1f, 1f)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.widget_playback_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }

    private fun buildNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java)
        val contentIntent = PendingIntent.getActivity(
            this,
            32,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.drawable.ic_widget_notification)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(getString(R.string.widget_playback_notification))
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .build()
    }

    companion object {
        const val ACTION_TOGGLE = "com.vinscent.vinscent.widget.TOGGLE_PLAYBACK"
        private const val CHANNEL_ID = "vinscent_widget_playback"
        private const val NOTIFICATION_ID = 2301
        private const val BOUNCE_INTERVAL_MS = 320L
    }
}
