package com.vinscent.vinscent.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.ImageView
import android.widget.RadioGroup
import android.widget.Toast
import com.vinscent.vinscent.R
import es.antonborri.home_widget.HomeWidgetPlugin

class CardWidgetConfigurationActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private lateinit var preview: ImageView
    private lateinit var selectedTilt: CardWidgetTilt
    private lateinit var tiltStore: CardWidgetTiltStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.activity_card_widget_configuration)
        tiltStore = CardWidgetTiltStore(this)
        selectedTilt = tiltStore.read(appWidgetId)
        preview = findViewById(R.id.card_widget_configuration_preview)
        loadPreview()

        val options = findViewById<RadioGroup>(R.id.card_widget_tilt_options)
        options.check(optionId(selectedTilt))
        updatePreview(selectedTilt)
        options.setOnCheckedChangeListener { _, checkedId ->
            selectedTilt = tiltForOption(checkedId)
            updatePreview(selectedTilt)
        }

        findViewById<android.view.View>(R.id.card_widget_configuration_done)
            .setOnClickListener { saveAndFinish() }
    }

    private fun loadPreview() {
        val widgetData = HomeWidgetPlugin.getData(this)
        val source = WidgetBitmapLoader.decode(
            widgetData.getString(WidgetStorageKeys.PARTNER_CARD_IMAGE_PATH, null),
            maximumWidth = 320,
            maximumHeight = 400,
        )
        if (source != null) {
            preview.setImageBitmap(source)
        }
    }

    private fun updatePreview(tilt: CardWidgetTilt) {
        preview.rotation = tilt.degrees
        preview.scaleX = tilt.previewScale
        preview.scaleY = tilt.previewScale
    }

    private fun saveAndFinish() {
        if (!tiltStore.save(appWidgetId, selectedTilt)) {
            Toast.makeText(
                this,
                R.string.card_widget_configuration_save_failed,
                Toast.LENGTH_SHORT,
            ).show()
            return
        }

        CardWidgetProvider.update(this, appWidgetId)
        val result = Intent().putExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            appWidgetId,
        )
        setResult(RESULT_OK, result)
        finish()
    }

    private fun optionId(tilt: CardWidgetTilt): Int {
        return when (tilt) {
            CardWidgetTilt.LEFT_FIVE -> R.id.card_widget_tilt_left_5
            CardWidgetTilt.LEFT_TWO_AND_HALF -> R.id.card_widget_tilt_left_2_5
            CardWidgetTilt.STRAIGHT -> R.id.card_widget_tilt_straight
            CardWidgetTilt.RIGHT_TWO_AND_HALF -> R.id.card_widget_tilt_right_2_5
            CardWidgetTilt.RIGHT_FIVE -> R.id.card_widget_tilt_right_5
        }
    }

    private fun tiltForOption(optionId: Int): CardWidgetTilt {
        return when (optionId) {
            R.id.card_widget_tilt_left_5 -> CardWidgetTilt.LEFT_FIVE
            R.id.card_widget_tilt_left_2_5 -> CardWidgetTilt.LEFT_TWO_AND_HALF
            R.id.card_widget_tilt_right_2_5 -> CardWidgetTilt.RIGHT_TWO_AND_HALF
            R.id.card_widget_tilt_right_5 -> CardWidgetTilt.RIGHT_FIVE
            else -> CardWidgetTilt.STRAIGHT
        }
    }
}
