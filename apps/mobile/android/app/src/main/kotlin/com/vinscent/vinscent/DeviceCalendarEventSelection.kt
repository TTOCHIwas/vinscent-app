package com.vinscent.vinscent

import android.provider.CalendarContract

internal data class DeviceCalendarEventMutationTarget(
    val selection: String,
    val arguments: Array<String>,
)

internal object DeviceCalendarEventSelection {
    fun mutationTarget(
        eventId: Long,
        calendarId: Long,
        packageName: String,
        marker: String,
    ): DeviceCalendarEventMutationTarget {
        return DeviceCalendarEventMutationTarget(
            selection =
                "${CalendarContract.Events._ID} = ? AND " +
                    "${CalendarContract.Events.CALENDAR_ID} = ? AND " +
                    "${CalendarContract.Events.CUSTOM_APP_PACKAGE} = ? AND " +
                    "${CalendarContract.Events.CUSTOM_APP_URI} = ?",
            arguments = arrayOf(
                eventId.toString(),
                calendarId.toString(),
                packageName,
                marker,
            ),
        )
    }
}
