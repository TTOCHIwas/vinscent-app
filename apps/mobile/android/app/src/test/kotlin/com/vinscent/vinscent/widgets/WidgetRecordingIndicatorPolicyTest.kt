package com.vinscent.vinscent.widgets

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetRecordingIndicatorPolicyTest {
    @Test
    fun `idle widget hides both recording indicators`() {
        val visibility = WidgetRecordingIndicatorPolicy.resolve(
            WidgetRecordingPhase.IDLE,
        )

        assertEquals(
            WidgetRecordingIndicatorVisibility(
                showRecordingRing = false,
                showUploadSpinner = false,
            ),
            visibility,
        )
    }

    @Test
    fun `recording widget shows only the recording ring`() {
        val visibility = WidgetRecordingIndicatorPolicy.resolve(
            WidgetRecordingPhase.RECORDING,
        )

        assertEquals(
            WidgetRecordingIndicatorVisibility(
                showRecordingRing = true,
                showUploadSpinner = false,
            ),
            visibility,
        )
    }

    @Test
    fun `uploading widget shows only the upload spinner`() {
        val visibility = WidgetRecordingIndicatorPolicy.resolve(
            WidgetRecordingPhase.UPLOADING,
        )

        assertEquals(
            WidgetRecordingIndicatorVisibility(
                showRecordingRing = false,
                showUploadSpinner = true,
            ),
            visibility,
        )
    }
}
