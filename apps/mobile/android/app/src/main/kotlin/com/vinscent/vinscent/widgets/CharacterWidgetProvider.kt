package com.vinscent.vinscent.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import com.vinscent.vinscent.MainActivity
import com.vinscent.vinscent.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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
        private val recordUri = Uri.parse("vinscent://widget/record?homeWidget")

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
            val recordIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                recordUri,
            )
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
                    if (hasAudio) playbackIntent(context) else recordIntent,
                )
                views.setOnClickPendingIntent(R.id.character_widget_record, recordIntent)
                manager.updateAppWidget(widgetId, views)
            }
            characterFrame?.recycle()
            source?.recycle()
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
    }
}
