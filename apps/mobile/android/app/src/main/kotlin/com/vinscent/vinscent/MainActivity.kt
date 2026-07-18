package com.vinscent.vinscent

import android.content.Intent
import android.os.Bundle
import com.vinscent.vinscent.widgets.WidgetPlaybackService
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        stopWidgetPlaybackForRecording(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        stopWidgetPlaybackForRecording(intent)
    }

    private fun stopWidgetPlaybackForRecording(intent: Intent?) {
        val uri = intent?.data ?: return
        val isRecordingLaunch =
            intent.action == HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION &&
                uri.scheme == "vinscent" &&
                uri.host == "widget" &&
                uri.path == "/record"
        if (isRecordingLaunch) {
            stopService(Intent(this, WidgetPlaybackService::class.java))
        }
    }
}
