package com.vinscent.vinscent

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.LocalDate
import java.time.ZoneOffset

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_CALENDAR_CHANNEL,
        ).setMethodCallHandler(::handleDeviceCalendarCall)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CALENDAR_PERMISSION_REQUEST_CODE) {
            return
        }
        pendingPermissionResult?.success(authorizationStatus())
        pendingPermissionResult = null
    }

    private fun handleDeviceCalendarCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "authorizationStatus" -> result.success(authorizationStatus())
                "requestFullAccess" -> requestCalendarAccess(result)
                "openSettings" -> {
                    openAppSettings()
                    result.success(null)
                }
                "listWritableCalendars" -> result.success(listWritableCalendars())
                "upsertEvent" -> result.success(upsertEvent(requireArguments(call)))
                "deleteEvent" -> {
                    deleteEvent(requireArguments(call))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: SecurityException) {
            result.error("device_calendar_permission_denied", error.message, null)
        } catch (error: IllegalArgumentException) {
            result.error("device_calendar_invalid_arguments", error.message, null)
        } catch (error: Exception) {
            result.error("device_calendar_failed", error.message, null)
        }
    }

    private fun authorizationStatus(): String {
        if (hasCalendarAccess()) {
            return "authorized"
        }
        val requested = getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
            .getBoolean(CALENDAR_PERMISSION_REQUESTED_KEY, false)
        return if (requested) "denied" else "notDetermined"
    }

    private fun requestCalendarAccess(result: MethodChannel.Result) {
        if (hasCalendarAccess()) {
            result.success("authorized")
            return
        }
        if (pendingPermissionResult != null) {
            result.error("device_calendar_permission_request_pending", null, null)
            return
        }
        getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
            .edit()
            .putBoolean(CALENDAR_PERMISSION_REQUESTED_KEY, true)
            .apply()
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            CALENDAR_PERMISSIONS,
            CALENDAR_PERMISSION_REQUEST_CODE,
        )
    }

    private fun hasCalendarAccess(): Boolean {
        return CALENDAR_PERMISSIONS.all { permission ->
            ContextCompat.checkSelfPermission(this, permission) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun openAppSettings() {
        startActivity(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun listWritableCalendars(): List<Map<String, Any?>> {
        requireCalendarAccess()
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.IS_PRIMARY,
        )
        val selection =
            "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ? AND " +
                "${CalendarContract.Calendars.VISIBLE} = 1"
        val arguments = arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString())
        return contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            arguments,
            "${CalendarContract.Calendars.IS_PRIMARY} DESC, " +
                "${CalendarContract.Calendars.CALENDAR_DISPLAY_NAME} ASC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID)
            val nameIndex = cursor.getColumnIndexOrThrow(
                CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            )
            val accountIndex = cursor.getColumnIndexOrThrow(
                CalendarContract.Calendars.ACCOUNT_NAME,
            )
            val primaryIndex = cursor.getColumnIndexOrThrow(
                CalendarContract.Calendars.IS_PRIMARY,
            )
            buildList {
                while (cursor.moveToNext()) {
                    add(
                        mapOf(
                            "id" to cursor.getLong(idIndex).toString(),
                            "name" to cursor.getString(nameIndex),
                            "accountName" to cursor.getString(accountIndex),
                            "isPrimary" to (cursor.getInt(primaryIndex) == 1),
                        ),
                    )
                }
            }
        } ?: emptyList()
    }

    private fun upsertEvent(arguments: Map<*, *>): String {
        requireCalendarAccess()
        val calendarId = arguments.requiredString("calendarId").toLongOrNull()
            ?: throw IllegalArgumentException("calendarId must be numeric on Android.")
        val sourceEventId = arguments.requiredString("sourceEventId")
        val marker = eventMarker(sourceEventId)
        val externalEventId = arguments["externalEventId"] as? String
        val eventId = findOwnedEventId(calendarId, externalEventId, marker)
        val start = LocalDate.parse(arguments.requiredString("eventDate"))
            .atStartOfDay(ZoneOffset.UTC)
            .toInstant()
            .toEpochMilli()
        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId)
            put(CalendarContract.Events.TITLE, arguments.requiredString("title"))
            put(CalendarContract.Events.DESCRIPTION, arguments["memo"] as? String)
            put(CalendarContract.Events.DTSTART, start)
            put(CalendarContract.Events.DTEND, start + MILLIS_PER_DAY)
            put(CalendarContract.Events.EVENT_TIMEZONE, "UTC")
            put(CalendarContract.Events.ALL_DAY, 1)
            put(CalendarContract.Events.HAS_ALARM, 0)
            put(CalendarContract.Events.RRULE, repeatRule(arguments["repeatRule"]))
            put(CalendarContract.Events.CUSTOM_APP_PACKAGE, packageName)
            put(CalendarContract.Events.CUSTOM_APP_URI, marker)
        }

        if (eventId != null) {
            val updated = contentResolver.update(
                ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId),
                values,
                ownedEventSelection(),
                arrayOf(packageName, marker),
            )
            if (updated == 1) {
                return eventId.toString()
            }
        }

        val inserted = contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            ?: throw IllegalStateException("The calendar provider rejected the event.")
        return ContentUris.parseId(inserted).toString()
    }

    private fun deleteEvent(arguments: Map<*, *>) {
        requireCalendarAccess()
        val calendarId = arguments.requiredString("calendarId").toLongOrNull()
            ?: throw IllegalArgumentException("calendarId must be numeric on Android.")
        val sourceEventId = arguments.requiredString("sourceEventId")
        val marker = eventMarker(sourceEventId)
        val externalEventId = arguments.requiredString("externalEventId")
        val eventId = findOwnedEventId(calendarId, externalEventId, marker) ?: return
        contentResolver.delete(
            ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId),
            ownedEventSelection(),
            arrayOf(packageName, marker),
        )
    }

    private fun findOwnedEventId(
        calendarId: Long,
        externalEventId: String?,
        marker: String,
    ): Long? {
        externalEventId?.toLongOrNull()?.let { id ->
            queryOwnedEventId(
                "${CalendarContract.Events._ID} = ? AND " +
                    "${CalendarContract.Events.CALENDAR_ID} = ? AND " +
                    ownedEventSelection(),
                arrayOf(id.toString(), calendarId.toString(), packageName, marker),
            )?.let { return it }
        }
        return queryOwnedEventId(
            "${CalendarContract.Events.CALENDAR_ID} = ? AND " + ownedEventSelection(),
            arrayOf(calendarId.toString(), packageName, marker),
        )
    }

    private fun queryOwnedEventId(selection: String, arguments: Array<String>): Long? {
        return contentResolver.query(
            CalendarContract.Events.CONTENT_URI,
            arrayOf(CalendarContract.Events._ID),
            selection,
            arguments,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getLong(0) else null
        }
    }

    private fun ownedEventSelection(): String {
        return "${CalendarContract.Events.CUSTOM_APP_PACKAGE} = ? AND " +
            "${CalendarContract.Events.CUSTOM_APP_URI} = ?"
    }

    private fun repeatRule(value: Any?): String? {
        return when (value) {
            "none" -> null
            "yearly" -> "FREQ=YEARLY"
            else -> throw IllegalArgumentException("Unsupported repeatRule: $value")
        }
    }

    private fun requireCalendarAccess() {
        if (!hasCalendarAccess()) {
            throw SecurityException("Calendar access has not been granted.")
        }
    }

    private fun requireArguments(call: MethodCall): Map<*, *> {
        return call.arguments as? Map<*, *>
            ?: throw IllegalArgumentException("Missing method arguments.")
    }

    private fun Map<*, *>.requiredString(key: String): String {
        return (this[key] as? String)?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("Missing $key.")
    }

    private fun eventMarker(sourceEventId: String): String {
        return "vinscent://calendar/event/$sourceEventId"
    }

    companion object {
        private const val DEVICE_CALENDAR_CHANNEL =
            "com.vinscent.vinscent/device_calendar"
        private const val PREFERENCES_NAME = "vinscent_device_calendar"
        private const val CALENDAR_PERMISSION_REQUESTED_KEY = "permission_requested"
        private const val CALENDAR_PERMISSION_REQUEST_CODE = 4701
        private const val MILLIS_PER_DAY = 86_400_000L
        private val CALENDAR_PERMISSIONS = arrayOf(
            Manifest.permission.READ_CALENDAR,
            Manifest.permission.WRITE_CALENDAR,
        )
    }
}
