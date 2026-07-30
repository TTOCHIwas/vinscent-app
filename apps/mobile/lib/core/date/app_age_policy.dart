import 'app_date_policy.dart';

const minimumServiceAgeYears = 14;

bool meetsMinimumServiceAge({
  required DateTime birthDate,
  required DateTime onDate,
}) {
  final normalizedBirthDate = calendarDateOnly(birthDate);
  final normalizedOnDate = calendarDateOnly(onDate);
  if (normalizedBirthDate.isAfter(normalizedOnDate)) {
    return false;
  }

  final eligibleFrom = DateTime(
    normalizedBirthDate.year + minimumServiceAgeYears,
    normalizedBirthDate.month,
    normalizedBirthDate.day,
  );
  return !eligibleFrom.isAfter(normalizedOnDate);
}
