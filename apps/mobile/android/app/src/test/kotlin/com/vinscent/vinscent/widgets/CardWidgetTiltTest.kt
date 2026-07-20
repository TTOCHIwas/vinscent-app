package com.vinscent.vinscent.widgets

import org.junit.Assert.assertEquals
import org.junit.Test

class CardWidgetTiltTest {
    @Test
    fun `stored values restore every supported tilt`() {
        CardWidgetTilt.entries.forEach { tilt ->
            assertEquals(tilt, CardWidgetTilt.fromStoredValue(tilt.storedValue))
        }
    }

    @Test
    fun `missing or invalid values use the straight default`() {
        assertEquals(CardWidgetTilt.STRAIGHT, CardWidgetTilt.fromStoredValue(null))
        assertEquals(CardWidgetTilt.STRAIGHT, CardWidgetTilt.fromStoredValue("invalid"))
    }
}
