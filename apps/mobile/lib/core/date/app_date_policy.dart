const appTimezone = 'Asia/Seoul';
const appTimezoneOffset = Duration(hours: 9);
final _calendarDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

DateTime currentAppDate({DateTime? now}) {
  final utcNow = (now ?? DateTime.now()).toUtc();
  final appNow = utcNow.add(appTimezoneOffset);
  return calendarDateOnly(appNow);
}

DateTime calendarDateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime calendarMonthOnly(DateTime value) {
  return DateTime(value.year, value.month);
}

bool isSameCalendarDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool isSameCalendarMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}

String formatCalendarDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? parseCalendarDate(String? value) {
  if (value == null || !_calendarDatePattern.hasMatch(value)) {
    return null;
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null || formatCalendarDate(parsed) != value) {
    return null;
  }

  return calendarDateOnly(parsed);
}

bool hasInvalidCalendarDate(String? value) {
  return value != null && parseCalendarDate(value) == null;
}

Duration durationUntilNextAppDate({DateTime? now}) {
  final utcNow = (now ?? DateTime.now()).toUtc();
  final appNow = utcNow.add(appTimezoneOffset);
  final nextAppMidnight = DateTime.utc(
    appNow.year,
    appNow.month,
    appNow.day + 1,
  );
  final nextAppMidnightUtc = nextAppMidnight.subtract(appTimezoneOffset);

  return nextAppMidnightUtc.difference(utcNow);
}
