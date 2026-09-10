class QuestionDeliveryTime {
  const QuestionDeliveryTime({required this.hour, required this.minute})
    : assert(hour >= 0 && hour <= 23),
      assert(minute >= 0 && minute <= 59);

  factory QuestionDeliveryTime.checked({
    required int hour,
    required int minute,
  }) {
    if (hour < 0 || hour > 23) {
      throw RangeError.range(hour, 0, 23, 'hour');
    }
    if (minute < 0 || minute > 59) {
      throw RangeError.range(minute, 0, 59, 'minute');
    }
    return QuestionDeliveryTime(hour: hour, minute: minute);
  }

  factory QuestionDeliveryTime.fromDatabase(String value) {
    final match = RegExp(
      r'^(\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?$',
    ).firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid question delivery time: $value');
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final second = int.parse(match.group(3) ?? '0');
    if (second != 0) {
      throw FormatException('Question delivery time must use whole minutes.');
    }

    try {
      return QuestionDeliveryTime.checked(hour: hour, minute: minute);
    } on RangeError {
      throw FormatException('Invalid question delivery time: $value');
    }
  }

  final int hour;
  final int minute;

  String toDatabase() {
    final paddedHour = hour.toString().padLeft(2, '0');
    final paddedMinute = minute.toString().padLeft(2, '0');
    return '$paddedHour:$paddedMinute:00';
  }

  String get label {
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = switch (hour % 12) {
      0 => 12,
      final value => value,
    };
    return '$period $displayHour:${minute.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) {
    return other is QuestionDeliveryTime &&
        other.hour == hour &&
        other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(hour, minute);
}
