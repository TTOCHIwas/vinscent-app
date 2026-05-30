import '../../../core/date/app_date_policy.dart';

int calculateRelationshipDayCount({
  required DateTime startDate,
  required DateTime today,
}) {
  final days =
      calendarDateOnly(today).difference(calendarDateOnly(startDate)).inDays +
      1;
  return days < 1 ? 1 : days;
}
