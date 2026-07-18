package com.vinscent.vinscent.widgets

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetRecordingTapPolicyTest {
    @Test
    fun `idle widget starts recording when microphone permission is granted`() {
        val target = WidgetRecordingTapPolicy.resolve(
            phase = WidgetRecordingPhase.IDLE,
            hasMicrophonePermission = true,
        )

        assertEquals(WidgetRecordingTapTarget.RECORDING_SERVICE, target)
    }

    @Test
    fun `idle widget opens permission activity when microphone permission is missing`() {
        val target = WidgetRecordingTapPolicy.resolve(
            phase = WidgetRecordingPhase.IDLE,
            hasMicrophonePermission = false,
        )

        assertEquals(WidgetRecordingTapTarget.PERMISSION_ACTIVITY, target)
    }

    @Test
    fun `recording widget always routes the second tap to the recording service`() {
        val target = WidgetRecordingTapPolicy.resolve(
            phase = WidgetRecordingPhase.RECORDING,
            hasMicrophonePermission = false,
        )

        assertEquals(WidgetRecordingTapTarget.RECORDING_SERVICE, target)
    }

    @Test
    fun `uploading widget ignores additional record taps`() {
        val target = WidgetRecordingTapPolicy.resolve(
            phase = WidgetRecordingPhase.UPLOADING,
            hasMicrophonePermission = true,
        )

        assertEquals(WidgetRecordingTapTarget.DISABLED, target)
    }
}
