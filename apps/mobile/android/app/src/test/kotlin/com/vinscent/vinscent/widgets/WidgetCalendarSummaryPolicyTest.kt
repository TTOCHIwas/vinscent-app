package com.vinscent.vinscent.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WidgetCalendarSummaryPolicyTest {
    @Test
    fun `hides a blank calendar summary`() {
        assertNull(WidgetCalendarSummaryPolicy.resolve("  ", "2"))
    }

    @Test
    fun `normalizes a calendar title and additional count`() {
        assertEquals(
            WidgetCalendarSummaryPresentation("한강 산책", 2),
            WidgetCalendarSummaryPolicy.resolve("  한강 산책  ", "2"),
        )
    }

    @Test
    fun `clamps an invalid additional count to zero`() {
        assertEquals(
            WidgetCalendarSummaryPresentation("100일", 0),
            WidgetCalendarSummaryPolicy.resolve("100일", "-1"),
        )
    }
}
