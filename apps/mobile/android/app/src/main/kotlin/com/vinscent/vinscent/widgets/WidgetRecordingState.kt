package com.vinscent.vinscent.widgets

import android.content.Context
import es.antonborri.home_widget.HomeWidgetPlugin

internal enum class WidgetRecordingPhase(val storedValue: String) {
    IDLE("idle"),
    RECORDING("recording"),
    UPLOADING("uploading");

    companion object {
        fun fromStoredValue(value: String?): WidgetRecordingPhase {
            return entries.firstOrNull { it.storedValue == value } ?: IDLE
        }
    }
}

internal enum class WidgetRecordingTapTarget {
    RECORDING_SERVICE,
    PERMISSION_ACTIVITY,
    DISABLED,
}

internal object WidgetRecordingTapPolicy {
    fun resolve(
        phase: WidgetRecordingPhase,
        hasMicrophonePermission: Boolean,
    ): WidgetRecordingTapTarget {
        return when (phase) {
            WidgetRecordingPhase.RECORDING -> WidgetRecordingTapTarget.RECORDING_SERVICE
            WidgetRecordingPhase.UPLOADING -> WidgetRecordingTapTarget.DISABLED
            WidgetRecordingPhase.IDLE -> {
                if (hasMicrophonePermission) {
                    WidgetRecordingTapTarget.RECORDING_SERVICE
                } else {
                    WidgetRecordingTapTarget.PERMISSION_ACTIVITY
                }
            }
        }
    }
}

internal class WidgetRecordingStateStore(context: Context) {
    private val data = HomeWidgetPlugin.getData(context)

    fun phase(): WidgetRecordingPhase {
        return WidgetRecordingPhase.fromStoredValue(
            data.getString(WidgetStorageKeys.RECORDING_PHASE, null),
        )
    }

    fun draftPath(): String? {
        return data.getString(WidgetStorageKeys.RECORDING_DRAFT_PATH, null)
    }

    fun markRecording(filePath: String, startedAtMs: Long) {
        data.edit()
            .putString(WidgetStorageKeys.RECORDING_PHASE, WidgetRecordingPhase.RECORDING.storedValue)
            .putString(WidgetStorageKeys.RECORDING_DRAFT_PATH, filePath)
            .putLong(WidgetStorageKeys.RECORDING_STARTED_AT, startedAtMs)
            .remove(WidgetStorageKeys.RECORDING_DURATION)
            .apply()
    }

    fun markUploading(filePath: String, durationMs: Int) {
        data.edit()
            .putString(WidgetStorageKeys.RECORDING_PHASE, WidgetRecordingPhase.UPLOADING.storedValue)
            .putString(WidgetStorageKeys.RECORDING_DRAFT_PATH, filePath)
            .putInt(WidgetStorageKeys.RECORDING_DURATION, durationMs)
            .remove(WidgetStorageKeys.RECORDING_STARTED_AT)
            .apply()
    }

    fun markIdle() {
        data.edit()
            .putString(WidgetStorageKeys.RECORDING_PHASE, WidgetRecordingPhase.IDLE.storedValue)
            .remove(WidgetStorageKeys.RECORDING_DRAFT_PATH)
            .remove(WidgetStorageKeys.RECORDING_STARTED_AT)
            .remove(WidgetStorageKeys.RECORDING_DURATION)
            .apply()
    }
}
