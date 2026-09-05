import EventKit
import Flutter
import Foundation
import UIKit

private struct VinscentDeviceCalendarError: Error {
  let code: String
  let message: String
}

final class VinscentDeviceCalendarBridge: NSObject, FlutterPlugin {
  private static let channelName = "com.vinscent.vinscent/device_calendar"
  private static let markerPrefix = "vinscent://calendar/event/"

  private let eventStore = EKEventStore()

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = VinscentDeviceCalendarBridge()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "authorizationStatus":
        result(Self.authorizationStatusValue())
      case "requestFullAccess":
        requestFullAccess(result: result)
      case "openSettings":
        openSettings(result: result)
      case "listWritableCalendars":
        try requireFullAccess()
        result(listWritableCalendars())
      case "upsertEvent":
        try requireFullAccess()
        result(try upsertEvent(arguments: try requireArguments(call)))
      case "deleteEvent":
        try requireFullAccess()
        try deleteEvent(arguments: try requireArguments(call))
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch let error as VinscentDeviceCalendarError {
      result(FlutterError(code: error.code, message: error.message, details: nil))
    } catch {
      result(
        FlutterError(
          code: "device_calendar_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private static func authorizationStatusValue() -> String {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) {
      if status == .fullAccess {
        return "authorized"
      }
      if status == .writeOnly {
        return "denied"
      }
    }
    switch status {
    case .notDetermined:
      return "notDetermined"
    case .restricted:
      return "restricted"
    case .denied:
      return "denied"
    case .authorized:
      return "authorized"
    @unknown default:
      return "unsupported"
    }
  }

  private func requestFullAccess(result: @escaping FlutterResult) {
    let completion: (Bool, Error?) -> Void = { _, error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "device_calendar_permission_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        result(Self.authorizationStatusValue())
      }
    }
    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToEvents(completion: completion)
    } else {
      eventStore.requestAccess(to: .event, completion: completion)
    }
  }

  private func openSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(
        FlutterError(
          code: "device_calendar_settings_unavailable",
          message: "The application settings URL is unavailable.",
          details: nil
        )
      )
      return
    }
    UIApplication.shared.open(url, options: [:]) { opened in
      result(
        opened
          ? nil
          : FlutterError(
              code: "device_calendar_settings_unavailable",
              message: "The application settings could not be opened.",
              details: nil
            )
      )
    }
  }

  private func listWritableCalendars() -> [[String: Any]] {
    let defaultIdentifier = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
    return eventStore.calendars(for: .event)
      .filter(\.allowsContentModifications)
      .sorted { left, right in
        if left.calendarIdentifier == defaultIdentifier {
          return true
        }
        if right.calendarIdentifier == defaultIdentifier {
          return false
        }
        return left.title.localizedCompare(right.title) == .orderedAscending
      }
      .map { calendar in
        [
          "id": calendar.calendarIdentifier,
          "name": calendar.title,
          "accountName": calendar.source.title,
          "isPrimary": calendar.calendarIdentifier == defaultIdentifier,
        ]
      }
  }

  private func upsertEvent(arguments: [String: Any]) throws -> String {
    let calendar = try writableCalendar(
      identifier: try requiredString("calendarId", in: arguments)
    )
    let sourceEventId = try requiredString("sourceEventId", in: arguments)
    let marker = Self.markerPrefix + sourceEventId
    let eventDate = try parseDate(try requiredString("eventDate", in: arguments))
    let previousEventDate = try optionalDate("previousEventDate", in: arguments)
    let externalEventId = arguments["externalEventId"] as? String
    let event = findOwnedEvent(
      externalEventId: externalEventId,
      marker: marker,
      candidateDates: [eventDate, previousEventDate].compactMap { $0 },
      calendar: calendar
    ) ?? EKEvent(eventStore: eventStore)
    let wasRecurring = event.recurrenceRules?.isEmpty == false

    event.calendar = calendar
    event.title = try requiredString("title", in: arguments)
    event.notes = arguments["memo"] as? String
    event.startDate = eventDate
    event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: eventDate)
    event.isAllDay = true
    event.url = URL(string: marker)
    event.recurrenceRules = try recurrenceRules(arguments["repeatRule"])

    try eventStore.save(
      event,
      span: wasRecurring ? .futureEvents : .thisEvent,
      commit: true
    )
    guard let identifier = event.eventIdentifier, !identifier.isEmpty else {
      throw bridgeError(
        code: "device_calendar_invalid_result",
        message: "The device calendar did not return an event identifier."
      )
    }
    return identifier
  }

  private func deleteEvent(arguments: [String: Any]) throws {
    let calendar = try writableCalendar(
      identifier: try requiredString("calendarId", in: arguments)
    )
    let sourceEventId = try requiredString("sourceEventId", in: arguments)
    let marker = Self.markerPrefix + sourceEventId
    let externalEventId = try requiredString("externalEventId", in: arguments)
    let eventDate = try parseDate(try requiredString("eventDate", in: arguments))
    guard let event = findOwnedEvent(
      externalEventId: externalEventId,
      marker: marker,
      candidateDates: [eventDate],
      calendar: calendar
    ) else {
      return
    }
    let span: EKSpan = event.recurrenceRules?.isEmpty == false
      ? .futureEvents
      : .thisEvent
    try eventStore.remove(event, span: span, commit: true)
  }

  private func findOwnedEvent(
    externalEventId: String?,
    marker: String,
    candidateDates: [Date],
    calendar: EKCalendar
  ) -> EKEvent? {
    if let externalEventId,
       let event = eventStore.event(withIdentifier: externalEventId),
       event.calendar.calendarIdentifier == calendar.calendarIdentifier,
       event.url?.absoluteString == marker {
      return event
    }
    for eventDate in candidateDates {
      guard let rangeStart = Calendar.current.date(
        byAdding: .day,
        value: -1,
        to: eventDate
      ), let rangeEnd = Calendar.current.date(
        byAdding: .day,
        value: 2,
        to: eventDate
      ) else {
        continue
      }
      let predicate = eventStore.predicateForEvents(
        withStart: rangeStart,
        end: rangeEnd,
        calendars: [calendar]
      )
      if let event = eventStore.events(matching: predicate).first(where: {
        $0.url?.absoluteString == marker
      }) {
        return event
      }
    }
    return nil
  }

  private func writableCalendar(identifier: String) throws -> EKCalendar {
    guard let calendar = eventStore.calendar(withIdentifier: identifier),
          calendar.allowsContentModifications else {
      throw bridgeError(
        code: "device_calendar_not_writable",
        message: "The selected calendar is not writable."
      )
    }
    return calendar
  }

  private func recurrenceRules(_ value: Any?) throws -> [EKRecurrenceRule]? {
    switch value as? String {
    case "none":
      return nil
    case "yearly":
      return [
        EKRecurrenceRule(
          recurrenceWith: .yearly,
          interval: 1,
          end: nil
        )
      ]
    default:
      throw bridgeError(
        code: "device_calendar_invalid_arguments",
        message: "Unsupported repeatRule."
      )
    }
  }

  private func parseDate(_ value: String) throws -> Date {
    let parts = value.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3,
          let date = Calendar.current.date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2])
          ) else {
      throw bridgeError(
        code: "device_calendar_invalid_arguments",
        message: "Invalid eventDate."
      )
    }
    return date
  }

  private func optionalDate(
    _ key: String,
    in arguments: [String: Any]
  ) throws -> Date? {
    guard let value = arguments[key] else {
      return nil
    }
    guard let dateString = value as? String, !dateString.isEmpty else {
      throw bridgeError(
        code: "device_calendar_invalid_arguments",
        message: "Invalid \(key)."
      )
    }
    return try parseDate(dateString)
  }

  private func requireFullAccess() throws {
    guard Self.authorizationStatusValue() == "authorized" else {
      throw bridgeError(
        code: "device_calendar_permission_denied",
        message: "Calendar access has not been granted."
      )
    }
  }

  private func requireArguments(_ call: FlutterMethodCall) throws -> [String: Any] {
    guard let arguments = call.arguments as? [String: Any] else {
      throw bridgeError(
        code: "device_calendar_invalid_arguments",
        message: "Missing method arguments."
      )
    }
    return arguments
  }

  private func requiredString(
    _ key: String,
    in arguments: [String: Any]
  ) throws -> String {
    guard let value = arguments[key] as? String, !value.isEmpty else {
      throw bridgeError(
        code: "device_calendar_invalid_arguments",
        message: "Missing \(key)."
      )
    }
    return value
  }

  private func bridgeError(
    code: String,
    message: String
  ) -> VinscentDeviceCalendarError {
    return VinscentDeviceCalendarError(code: code, message: message)
  }
}
