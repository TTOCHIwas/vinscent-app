import 'couple_calendar_event.dart';

class CoupleCalendarEventMapper {
  const CoupleCalendarEventMapper();

  CoupleCalendarEvent mapOccurrence(
    Map<String, dynamic> json, {
    Map<String, String> previewUrlsByPath = const {},
  }) {
    final previewPath = json['artwork_preview_path'] as String?;
    final drawingDataPath = json['artwork_data_path'] as String?;

    return CoupleCalendarEvent(
      id: json['event_id'] as String,
      coupleId: json['couple_id'] as String,
      title: json['title'] as String,
      eventDate: _parseDate(json['event_date']),
      occurrenceDate: _parseDate(json['occurrence_date']),
      repeatRule: CoupleCalendarEventRepeatRule.fromJson(
        json['repeat_rule'] as String,
      ),
      memo: json['memo'] as String?,
      artwork: previewPath == null || drawingDataPath == null
          ? null
          : CoupleCalendarEventArtwork(
              previewPath: previewPath,
              drawingDataPath: drawingDataPath,
              previewUrl: previewUrlsByPath[previewPath],
            ),
      revision: json['revision'] as int,
      createdByUserId: json['created_by_user_id'] as String,
      updatedByUserId: json['updated_by_user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      reminder: _mapReminder(json),
    );
  }

  CoupleCalendarEventReminder _mapReminder(Map<String, dynamic> json) {
    final (hour, minute) = _parseTime(json['own_reminder_time']);
    return CoupleCalendarEventReminder(
      isEnabled: json['own_reminder_enabled'] as bool? ?? false,
      offsetDays: json['own_reminder_offset_days'] as int? ?? 0,
      hour: hour,
      minute: minute,
    );
  }

  DateTime _parseDate(Object? value) {
    if (value is! String) {
      throw const FormatException('Calendar event date is invalid.');
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw const FormatException('Calendar event date is invalid.');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  (int, int) _parseTime(Object? value) {
    if (value is! String) {
      throw const FormatException('Calendar event reminder time is invalid.');
    }

    final match = RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?$').firstMatch(value);
    final hour = int.tryParse(match?.group(1) ?? '');
    final minute = int.tryParse(match?.group(2) ?? '');
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw const FormatException('Calendar event reminder time is invalid.');
    }
    return (hour, minute);
  }
}
