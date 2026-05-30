int calculateRelationshipDayCount({
  required DateTime startDate,
  required DateTime today,
}) {
  final days = _dateOnly(today).difference(_dateOnly(startDate)).inDays + 1;
  return days < 1 ? 1 : days;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
