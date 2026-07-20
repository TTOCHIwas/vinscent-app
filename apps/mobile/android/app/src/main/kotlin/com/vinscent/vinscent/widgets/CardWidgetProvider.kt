package com.vinscent.vinscent.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.vinscent.vinscent.MainActivity
import com.vinscent.vinscent.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class CardWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        updateWidgets(context, appWidgetManager, appWidgetIds, widgetData)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        CardWidgetTiltStore(context).remove(appWidgetIds)
        super.onDeleted(context, appWidgetIds)
    }

    companion object {
        fun update(context: Context, appWidgetId: Int) {
            if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
            updateWidgets(
                context = context,
                appWidgetManager = AppWidgetManager.getInstance(context),
                appWidgetIds = intArrayOf(appWidgetId),
                widgetData = HomeWidgetPlugin.getData(context),
            )
        }

        private fun updateWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
            widgetData: SharedPreferences,
        ) {
            val source = WidgetBitmapLoader.decode(
                widgetData.getString(WidgetStorageKeys.PARTNER_CARD_IMAGE_PATH, null),
                maximumWidth = 384,
                maximumHeight = 480,
            )
            val openIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("vinscent://widget/card?homeWidget"),
            )
            val tiltStore = CardWidgetTiltStore(context)

            appWidgetIds.forEach { widgetId ->
                val tilt = tiltStore.read(widgetId)
                val views = RemoteViews(context.packageName, tilt.layoutResource)
                if (source == null) {
                    views.setImageViewResource(
                        R.id.card_widget_image,
                        R.drawable.ic_widget_card_placeholder,
                    )
                } else {
                    views.setImageViewBitmap(R.id.card_widget_image, source)
                }
                views.setOnClickPendingIntent(R.id.card_widget_root, openIntent)
                views.setOnClickPendingIntent(R.id.card_widget_image, openIntent)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
            source?.recycle()
        }
    }
}
