package com.vinscent.vinscent

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

class DeviceCalendarEventSelectionTest {
    @Test
    fun `mutation target scopes the collection query to owned event`() {
        val target = DeviceCalendarEventSelection.mutationTarget(
            eventId = 1082L,
            calendarId = 21L,
            packageName = "com.vinscent.vinscent",
            marker = "vinscent://calendar/event/source-id",
        )

        assertEquals(
            "_id = ? AND calendar_id = ? AND customAppPackage = ? AND customAppUri = ?",
            target.selection,
        )
        assertArrayEquals(
            arrayOf(
                "1082",
                "21",
                "com.vinscent.vinscent",
                "vinscent://calendar/event/source-id",
            ),
            target.arguments,
        )
    }
}
