const appTimezone = 'Asia/Seoul';
const appTimezoneOffset = Duration(hours: 9);

DateTime currentAppDate({DateTime? now}) {
  final utcNow = (now ?? DateTime.now()).toUtc();
  final appNow = utcNow.add(appTimezoneOffset);
  return calendarDateOnly(appNow);
}

DateTime calendarDateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
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
