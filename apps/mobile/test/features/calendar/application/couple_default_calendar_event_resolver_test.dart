import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/application/couple_default_calendar_event_resolver.dart';
import 'package:vinscent/features/calendar/data/couple_member_birthday.dart';

void main() {
  const resolver = CoupleDefaultCalendarEventResolver();
  final birthdays = [
    CoupleMemberBirthday(
      role: CoupleMemberRole.self,
      displayName: '또치',
      birthDate: DateTime(1990, 7, 28),
    ),
    CoupleMemberBirthday(
      role: CoupleMemberRole.partner,
      displayName: '초코',
      birthDate: DateTime(1992, 2, 29),
    ),
  ];

  test('adds each member birthday as an annual default event', () {
    final occurrences = resolver.resolve(
      relationshipStartDate: DateTime(2026, 1, 1),
      date: DateTime(2026, 7, 28),
      birthdays: birthdays,
    );

    expect(occurrences.map((occurrence) => occurrence.label), ['내 생일']);
  });

  test('maps a February 29 birthday to February 28 in non-leap years', () {
    final occurrences = resolver.resolve(
      relationshipStartDate: DateTime(2026, 1, 1),
      date: DateTime(2027, 2, 28),
      birthdays: birthdays,
    );

    expect(occurrences.map((occurrence) => occurrence.label), ['초코 생일']);
  });

  test('keeps relationship anniversaries ahead of birthdays', () {
    final occurrences = resolver.resolve(
      relationshipStartDate: DateTime(2025, 7, 28),
      date: DateTime(2026, 7, 28),
      birthdays: birthdays,
    );

    expect(occurrences.map((occurrence) => occurrence.label), ['1주년', '내 생일']);
  });

  test('does not expose birthdays before the relationship starts', () {
    final occurrences = resolver.resolve(
      relationshipStartDate: DateTime(2026, 8, 1),
      date: DateTime(2026, 7, 28),
      birthdays: birthdays,
    );

    expect(occurrences, isEmpty);
  });
}
