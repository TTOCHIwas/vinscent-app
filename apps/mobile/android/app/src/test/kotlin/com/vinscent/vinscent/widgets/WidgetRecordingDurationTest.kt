package com.vinscent.vinscent.widgets

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetRecordingDurationTest {
    @Test
    fun `maximum recording duration is fifteen seconds`() {
        assertEquals(15_000, WidgetRecordingDuration.MAXIMUM_MS)
    }

    @Test
    fun `remaining duration decreases from full to empty`() {
        assertEquals(15_000, WidgetRecordingDuration.remainingMs(0))
        assertEquals(10_000, WidgetRecordingDuration.remainingMs(5_000))
        assertEquals(0, WidgetRecordingDuration.remainingMs(15_000))
    }

    @Test
    fun `remaining duration clamps values outside the recording window`() {
        assertEquals(15_000, WidgetRecordingDuration.remainingMs(-1))
        assertEquals(0, WidgetRecordingDuration.remainingMs(20_000))
    }

    @Test
    fun `elapsed duration uses the stored recording start time`() {
        assertEquals(
            4_000,
            WidgetRecordingDuration.elapsedSince(
                startedAtMs = 10_000,
                nowMs = 14_000,
            ),
        )
        assertEquals(0, WidgetRecordingDuration.elapsedSince(null, 14_000))
    }
}
