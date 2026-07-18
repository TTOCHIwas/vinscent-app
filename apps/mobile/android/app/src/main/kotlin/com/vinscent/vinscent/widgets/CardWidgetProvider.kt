package com.vinscent.vinscent.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.vinscent.vinscent.MainActivity
import com.vinscent.vinscent.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class CardWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
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

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.card_widget)
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
