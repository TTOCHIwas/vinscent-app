package com.vinscent.vinscent.widgets

import android.Manifest
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import com.vinscent.vinscent.R
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class CharacterWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        updateWidgets(context, appWidgetManager, appWidgetIds, widgetData, false)
    }

    companion object {
        fun updateAll(context: Context, raised: Boolean = false) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, CharacterWidgetProvider::class.java),
            )
            updateWidgets(
                context,
                manager,
                ids,
                HomeWidgetPlugin.getData(context),
                raised,
            )
        }

        private fun updateWidgets(
            context: Context,
            manager: AppWidgetManager,
            ids: IntArray,
            data: SharedPreferences,
            raised: Boolean,
        ) {
            val source = WidgetBitmapLoader.decode(
                data.getString(WidgetStorageKeys.CHARACTER_IMAGE_PATH, null),
                maximumWidth = 384,
                maximumHeight = 384,
            )
            val audioPath = data.getString(WidgetStorageKeys.RECORDING_AUDIO_PATH, null)
            val hasAudio = !audioPath.isNullOrBlank()
            val recordingStateStore = WidgetRecordingStateStore(context)
            val recordingPhase = recordingStateStore.phase()
            val recordingProgress = WidgetRecordingDuration.remainingMs(
                WidgetRecordingDuration.elapsedSince(
                    startedAtMs = recordingStateStore.recordingStartedAtMs(),
                    nowMs = System.currentTimeMillis(),
                ).toLong(),
            )
            val tapTarget = WidgetRecordingTapPolicy.resolve(
                phase = recordingPhase,
                hasMicrophonePermission = context.checkSelfPermission(
                    Manifest.permission.RECORD_AUDIO,
                ) == PackageManager.PERMISSION_GRANTED,
            )
            val recordIntent = when (tapTarget) {
                WidgetRecordingTapTarget.RECORDING_SERVICE -> recordingIntent(context)
                WidgetRecordingTapTarget.PERMISSION_ACTIVITY -> permissionIntent(context)
                WidgetRecordingTapTarget.DISABLED -> noOpIntent(context)
            }
            val characterFrame = source?.let {
                WidgetBitmapLoader.characterFrame(it, raised)
            }

            ids.forEach { widgetId ->
                val views = RemoteViews(context.packageName, R.layout.character_widget)
                if (characterFrame == null) {
                    views.setImageViewResource(
                        R.id.character_widget_image,
                        R.drawable.ic_widget_character_placeholder,
                    )
                } else {
                    views.setImageViewBitmap(
                        R.id.character_widget_image,
                        characterFrame,
                    )
                }
                views.setOnClickPendingIntent(
                    R.id.character_widget_image,
                    if (recordingPhase == WidgetRecordingPhase.IDLE) {
                        if (hasAudio) playbackIntent(context) else recordIntent
                    } else {
                        noOpIntent(context)
                    },
                )
                val recordIcon = when (recordingPhase) {
                    WidgetRecordingPhase.IDLE -> R.drawable.ic_widget_mic
                    WidgetRecordingPhase.RECORDING -> R.drawable.ic_widget_stop
                    WidgetRecordingPhase.UPLOADING -> R.drawable.ic_widget_mic
                }
                val recordBackground = when (recordingPhase) {
                    WidgetRecordingPhase.RECORDING ->
                        R.drawable.widget_record_button_recording_background
                    else -> R.drawable.widget_record_button_background
                }
                val recordDescription = when (recordingPhase) {
                    WidgetRecordingPhase.IDLE -> R.string.character_widget_record
                    WidgetRecordingPhase.RECORDING -> R.string.character_widget_stop_recording
                    WidgetRecordingPhase.UPLOADING -> R.string.character_widget_uploading
                }
                val indicatorVisibility = WidgetRecordingIndicatorPolicy.resolve(recordingPhase)
                views.setImageViewResource(R.id.character_widget_record_icon, recordIcon)
                views.setViewVisibility(
                    R.id.character_widget_record_icon,
                    if (indicatorVisibility.showUploadSpinner) View.GONE else View.VISIBLE,
                )
                views.setViewVisibility(
                    R.id.character_widget_recording_indicator,
                    if (indicatorVisibility.showRecordingRing) View.VISIBLE else View.GONE,
                )
                views.setProgressBar(
                    R.id.character_widget_recording_indicator,
                    WidgetRecordingDuration.MAXIMUM_MS,
                    recordingProgress,
                    false,
                )
                views.setViewVisibility(
                    R.id.character_widget_record_progress,
                    if (indicatorVisibility.showUploadSpinner) View.VISIBLE else View.GONE,
                )
                views.setInt(
                    R.id.character_widget_record,
                    "setBackgroundResource",
                    recordBackground,
                )
                views.setContentDescription(
                    R.id.character_widget_record,
                    context.getString(recordDescription),
                )
                views.setOnClickPendingIntent(R.id.character_widget_record, recordIntent)
                manager.updateAppWidget(widgetId, views)
            }
            characterFrame?.recycle()
            source?.recycle()
        }

        fun updateRecordingProgress(context: Context, elapsedMs: Long) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, CharacterWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return

            val views = RemoteViews(context.packageName, R.layout.character_widget)
            views.setProgressBar(
                R.id.character_widget_recording_indicator,
                WidgetRecordingDuration.MAXIMUM_MS,
                WidgetRecordingDuration.remainingMs(elapsedMs),
                false,
            )
            manager.partiallyUpdateAppWidget(ids, views)
        }

        private fun recordingIntent(context: Context): PendingIntent {
            val intent = Intent(context, WidgetRecordingService::class.java).apply {
                action = WidgetRecordingService.ACTION_TOGGLE
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PendingIntent.getForegroundService(context, 41, intent, flags)
            } else {
                PendingIntent.getService(context, 41, intent, flags)
            }
        }

        private fun permissionIntent(context: Context): PendingIntent {
            val intent = Intent(context, WidgetRecordingPermissionActivity::class.java)
            return PendingIntent.getActivity(
                context,
                42,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun noOpIntent(context: Context): PendingIntent {
            val intent = Intent(context, CharacterWidgetProvider::class.java).apply {
                action = ACTION_NO_OP
            }
            return PendingIntent.getBroadcast(
                context,
                43,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun playbackIntent(context: Context): PendingIntent {
            val intent = Intent(context, WidgetPlaybackService::class.java).apply {
                action = WidgetPlaybackService.ACTION_TOGGLE
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PendingIntent.getForegroundService(context, 31, intent, flags)
            } else {
                PendingIntent.getService(context, 31, intent, flags)
            }
        }

        private const val ACTION_NO_OP = "com.vinscent.vinscent.widget.NO_OP"
    }
}
