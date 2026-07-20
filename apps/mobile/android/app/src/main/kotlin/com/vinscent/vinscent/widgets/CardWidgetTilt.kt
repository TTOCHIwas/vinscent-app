package com.vinscent.vinscent.widgets

import android.content.Context
import com.vinscent.vinscent.R

internal enum class CardWidgetTilt(
    val storedValue: String,
    val degrees: Float,
    val layoutResource: Int,
    val previewScale: Float = 1f,
) {
    LEFT_FIVE(
        storedValue = "left_5",
        degrees = -5f,
        layoutResource = R.layout.card_widget_tilt_left_5,
        previewScale = 0.95f,
    ),
    LEFT_TWO_AND_HALF(
        storedValue = "left_2_5",
        degrees = -2.5f,
        layoutResource = R.layout.card_widget_tilt_left_2_5,
    ),
    STRAIGHT(
        storedValue = "straight",
        degrees = 0f,
        layoutResource = R.layout.card_widget,
    ),
    RIGHT_TWO_AND_HALF(
        storedValue = "right_2_5",
        degrees = 2.5f,
        layoutResource = R.layout.card_widget_tilt_right_2_5,
    ),
    RIGHT_FIVE(
        storedValue = "right_5",
        degrees = 5f,
        layoutResource = R.layout.card_widget_tilt_right_5,
        previewScale = 0.95f,
    );

    companion object {
        fun fromStoredValue(value: String?): CardWidgetTilt {
            return entries.firstOrNull { it.storedValue == value } ?: STRAIGHT
        }
    }
}

internal class CardWidgetTiltStore(context: Context) {
    private val preferences = context.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    fun read(appWidgetId: Int): CardWidgetTilt {
        return CardWidgetTilt.fromStoredValue(
            preferences.getString(key(appWidgetId), null),
        )
    }

    fun save(appWidgetId: Int, tilt: CardWidgetTilt): Boolean {
        return preferences.edit()
            .putString(key(appWidgetId), tilt.storedValue)
            .commit()
    }

    fun remove(appWidgetIds: IntArray) {
        preferences.edit().apply {
            appWidgetIds.forEach { remove(key(it)) }
        }.apply()
    }

    private fun key(appWidgetId: Int): String = "card_widget_tilt_$appWidgetId"

    private companion object {
        const val PREFERENCES_NAME = "card_widget_configuration"
    }
}
