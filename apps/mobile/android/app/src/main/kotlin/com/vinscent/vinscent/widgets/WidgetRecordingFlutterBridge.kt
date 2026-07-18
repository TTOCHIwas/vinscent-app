package com.vinscent.vinscent.widgets

import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout

internal data class WidgetRecordingUploadOutcome(
    val success: Boolean,
    val retryable: Boolean,
)

internal class WidgetRecordingFlutterBridge(private val context: Context) {
    suspend fun upload(
        recordingId: String,
        filePath: String,
        durationMs: Int,
    ): WidgetRecordingUploadOutcome = withContext(Dispatchers.Main.immediate) {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(context)
        loader.ensureInitializationComplete(context, null)

        val engine = FlutterEngine(context)
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        val ready = CompletableDeferred<Unit>()
        channel.setMethodCallHandler { call, result ->
            if (call.method == METHOD_READY) {
                if (!ready.isCompleted) ready.complete(Unit)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        try {
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    DART_ENTRYPOINT,
                ),
            )
            withTimeout(READY_TIMEOUT_MS) { ready.await() }
            invokeUpload(
                channel = channel,
                arguments = mapOf(
                    "recordingId" to recordingId,
                    "filePath" to filePath,
                    "durationMs" to durationMs,
                ),
            )
        } finally {
            channel.setMethodCallHandler(null)
            engine.destroy()
        }
    }

    private suspend fun invokeUpload(
        channel: MethodChannel,
        arguments: Map<String, Any>,
    ): WidgetRecordingUploadOutcome {
        val response = CompletableDeferred<WidgetRecordingUploadOutcome>()
        channel.invokeMethod(METHOD_UPLOAD, arguments, object : MethodChannel.Result {
            override fun success(result: Any?) {
                val values = result as? Map<*, *>
                response.complete(
                    WidgetRecordingUploadOutcome(
                        success = values?.get("success") == true,
                        retryable = values?.get("retryable") == true,
                    ),
                )
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                response.complete(WidgetRecordingUploadOutcome(false, true))
            }

            override fun notImplemented() {
                response.complete(WidgetRecordingUploadOutcome(false, false))
            }
        })
        return withTimeout(UPLOAD_TIMEOUT_MS) { response.await() }
    }

    companion object {
        private const val CHANNEL_NAME =
            "com.vinscent.vinscent/widget_recording_upload"
        private const val DART_ENTRYPOINT = "widgetRecordingUploadMain"
        private const val METHOD_READY = "ready"
        private const val METHOD_UPLOAD = "upload"
        private const val READY_TIMEOUT_MS = 30000L
        private const val UPLOAD_TIMEOUT_MS = 90000L
    }
}
