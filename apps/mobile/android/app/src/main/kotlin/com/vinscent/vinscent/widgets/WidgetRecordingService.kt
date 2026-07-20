package com.vinscent.vinscent.widgets

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import com.vinscent.vinscent.R
import java.io.File
import java.util.UUID

class WidgetRecordingService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var stateStore: WidgetRecordingStateStore
    private var recorder: MediaRecorder? = null
    private var draftFile: File? = null
    private var recordingId: String? = null
    private var startedAtElapsedMs = 0L
    private var stopping = false
    private val progressUpdate = object : Runnable {
        override fun run() {
            if (recorder == null || stopping) return
            val elapsedMs = SystemClock.elapsedRealtime() - startedAtElapsedMs
            CharacterWidgetProvider.updateRecordingProgress(
                this@WidgetRecordingService,
                elapsedMs,
            )
            if (elapsedMs < WidgetRecordingDuration.MAXIMUM_MS) {
                mainHandler.postDelayed(this, PROGRESS_UPDATE_INTERVAL_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        stateStore = WidgetRecordingStateStore(this)
        clearInterruptedRecording()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startRecordingIfPossible()
            ACTION_STOP -> stopAndUpload()
            ACTION_TOGGLE -> {
                if (recorder == null) {
                    startRecordingIfPossible()
                } else {
                    stopAndUpload()
                }
            }
            else -> stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopProgressUpdates()
        if (recorder != null) {
            discardInterruptedRecording()
        }
        super.onDestroy()
    }

    private fun startRecordingIfPossible() {
        if (recorder != null) {
            return
        }
        if (stateStore.phase() == WidgetRecordingPhase.UPLOADING) {
            stopSelf()
            return
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            stateStore.markIdle()
            CharacterWidgetProvider.updateAll(this)
            stopSelf()
            return
        }

        stopService(Intent(this, WidgetPlaybackService::class.java))
        val nextRecordingId = UUID.randomUUID().toString()
        val nextDraft = createDraftFile(nextRecordingId)
        val nextRecorder = createRecorder(nextDraft)

        try {
            startMicrophoneForeground()
            nextRecorder.prepare()
            nextRecorder.start()
        } catch (_: Exception) {
            nextRecorder.release()
            nextDraft.delete()
            stateStore.markIdle()
            CharacterWidgetProvider.updateAll(this)
            stopForegroundCompat()
            stopSelf()
            return
        }

        recorder = nextRecorder
        draftFile = nextDraft
        recordingId = nextRecordingId
        startedAtElapsedMs = SystemClock.elapsedRealtime()
        stopping = false
        stateStore.markRecording(nextDraft.absolutePath, System.currentTimeMillis())
        CharacterWidgetProvider.updateAll(this)
        startProgressUpdates()
    }

    private fun createRecorder(output: File): MediaRecorder {
        val nextRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        return nextRecorder.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioEncodingBitRate(AUDIO_BIT_RATE)
            setAudioSamplingRate(AUDIO_SAMPLE_RATE)
            setOutputFile(output.absolutePath)
            setMaxDuration(WidgetRecordingDuration.MAXIMUM_MS)
            setOnInfoListener { _, what, _ ->
                if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                    mainHandler.post { stopAndUpload() }
                }
            }
        }
    }

    private fun stopAndUpload() {
        if (stopping) return
        val activeRecorder = recorder ?: run {
            stopSelf()
            return
        }
        stopping = true
        stopProgressUpdates()

        val elapsedMs = (SystemClock.elapsedRealtime() - startedAtElapsedMs)
            .coerceIn(1L, WidgetRecordingDuration.MAXIMUM_MS.toLong())
            .toInt()
        val file = draftFile
        val id = recordingId
        var stoppedCleanly = false
        try {
            activeRecorder.stop()
            stoppedCleanly = true
        } catch (_: RuntimeException) {
        } finally {
            activeRecorder.release()
            recorder = null
        }

        if (stoppedCleanly && file?.isFile == true && file.length() > 0L && id != null) {
            stateStore.markUploading(file.absolutePath, elapsedMs)
            CharacterWidgetProvider.updateAll(this)
            val enqueued = WidgetRecordingUploadWorker.enqueue(
                context = this,
                recordingId = id,
                filePath = file.absolutePath,
                durationMs = elapsedMs,
            )
            if (!enqueued) {
                file.delete()
                stateStore.markIdle()
                CharacterWidgetProvider.updateAll(this)
            }
        } else {
            file?.delete()
            stateStore.markIdle()
            CharacterWidgetProvider.updateAll(this)
        }

        draftFile = null
        recordingId = null
        stopForegroundCompat()
        stopSelf()
    }

    private fun clearInterruptedRecording() {
        if (stateStore.phase() != WidgetRecordingPhase.RECORDING) return
        stateStore.draftPath()?.let(::File)?.delete()
        stateStore.markIdle()
        CharacterWidgetProvider.updateAll(this)
    }

    private fun discardInterruptedRecording() {
        stopProgressUpdates()
        runCatching { recorder?.stop() }
        recorder?.release()
        recorder = null
        draftFile?.delete()
        draftFile = null
        recordingId = null
        stateStore.markIdle()
        CharacterWidgetProvider.updateAll(this)
    }

    private fun startProgressUpdates() {
        mainHandler.removeCallbacks(progressUpdate)
        mainHandler.post(progressUpdate)
    }

    private fun stopProgressUpdates() {
        mainHandler.removeCallbacks(progressUpdate)
    }

    private fun createDraftFile(id: String): File {
        val directory = File(filesDir, DRAFT_DIRECTORY).apply { mkdirs() }
        return File(directory, "$id.m4a")
    }

    private fun startMicrophoneForeground() {
        val notification = buildRecordingNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundCompat() {
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.widget_recording_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }

    private fun buildRecordingNotification(): Notification {
        val stopIntent = Intent(this, WidgetRecordingService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(
                this,
                2402,
                stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        } else {
            PendingIntent.getService(
                this,
                2402,
                stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.drawable.ic_widget_notification)
            .setContentTitle(getString(R.string.widget_recording_notification_title))
            .setContentText(getString(R.string.widget_recording_notification_text))
            .setOngoing(true)
            .setUsesChronometer(true)
            .setWhen(System.currentTimeMillis())
            .setCategory(Notification.CATEGORY_SERVICE)
            .addAction(
                Notification.Action.Builder(
                    null,
                    getString(R.string.widget_recording_stop),
                    stopPendingIntent,
                ).build(),
            )
            .build()
    }

    companion object {
        const val ACTION_START = "com.vinscent.vinscent.widget.START_RECORDING"
        const val ACTION_STOP = "com.vinscent.vinscent.widget.STOP_RECORDING"
        const val ACTION_TOGGLE = "com.vinscent.vinscent.widget.TOGGLE_RECORDING"
        private const val DRAFT_DIRECTORY = "widget_recordings"
        private const val CHANNEL_ID = "vinscent_widget_recording"
        private const val NOTIFICATION_ID = 2401
        private const val PROGRESS_UPDATE_INTERVAL_MS = 250L
        private const val AUDIO_SAMPLE_RATE = 44100
        private const val AUDIO_BIT_RATE = 96000
    }
}
