enum CoupleCalendarEventRepeatRule {
  none,
  yearly;

  factory CoupleCalendarEventRepeatRule.fromJson(String value) {
    return switch (value) {
      'none' => CoupleCalendarEventRepeatRule.none,
      'yearly' => CoupleCalendarEventRepeatRule.yearly,
      _ => throw FormatException('Unknown calendar event repeat rule: $value'),
    };
  }

  String toJson() {
    return switch (this) {
      CoupleCalendarEventRepeatRule.none => 'none',
      CoupleCalendarEventRepeatRule.yearly => 'yearly',
    };
  }
}

class CoupleCalendarEvent {
  const CoupleCalendarEvent({
    required this.id,
    required this.coupleId,
    required this.title,
    required this.eventDate,
    required this.occurrenceDate,
    required this.repeatRule,
    required this.memo,
    required this.revision,
    required this.createdByUserId,
    required this.updatedByUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.reminder,
    this.artwork,
  });

  final String id;
  final String coupleId;
  final String title;
  final DateTime eventDate;
  final DateTime occurrenceDate;
  final CoupleCalendarEventRepeatRule repeatRule;
  final String? memo;
  final CoupleCalendarEventArtwork? artwork;
  final int revision;
  final String createdByUserId;
  final String updatedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CoupleCalendarEventReminder reminder;
}

class CoupleCalendarEventArtwork {
  const CoupleCalendarEventArtwork({
    required this.previewPath,
    required this.drawingDataPath,
    this.previewUrl,
  });

  final String previewPath;
  final String drawingDataPath;
  final String? previewUrl;
}

class CoupleCalendarEventReminder {
  const CoupleCalendarEventReminder({
    required this.isEnabled,
    required this.offsetDays,
    required this.hour,
    required this.minute,
  });

  const CoupleCalendarEventReminder.disabled()
    : isEnabled = false,
      offsetDays = 0,
      hour = 9,
      minute = 0;

  final bool isEnabled;
  final int offsetDays;
  final int hour;
  final int minute;

  String get serializedTime {
    final formattedHour = hour.toString().padLeft(2, '0');
    final formattedMinute = minute.toString().padLeft(2, '0');
    return '$formattedHour:$formattedMinute:00';
  }
}
