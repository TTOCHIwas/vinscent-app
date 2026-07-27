import '../../../core/date/app_date_policy.dart';
import '../data/couple_member_birthday.dart';
import 'couple_anniversary_resolver.dart';

enum CoupleDefaultCalendarEventKind { relationshipAnniversary, birthday }

class CoupleDefaultCalendarEventOccurrence {
  const CoupleDefaultCalendarEventOccurrence({
    required this.kind,
    required this.label,
    required this.date,
  });

  final CoupleDefaultCalendarEventKind kind;
  final String label;
  final DateTime date;
}

class CoupleDefaultCalendarEventResolver {
  const CoupleDefaultCalendarEventResolver({
    CoupleAnniversaryResolver anniversaryResolver =
        const CoupleAnniversaryResolver(),
  }) : _anniversaryResolver = anniversaryResolver;

  final CoupleAnniversaryResolver _anniversaryResolver;

  List<CoupleDefaultCalendarEventOccurrence> resolve({
    required DateTime relationshipStartDate,
    required DateTime date,
    required Iterable<CoupleMemberBirthday> birthdays,
  }) {
    final normalizedStartDate = calendarDateOnly(relationshipStartDate);
    final normalizedDate = calendarDateOnly(date);
    if (normalizedDate.isBefore(normalizedStartDate)) {
      return const [];
    }

    final occurrences = <CoupleDefaultCalendarEventOccurrence>[
      for (final anniversary in _anniversaryResolver.resolve(
        startDate: normalizedStartDate,
        date: normalizedDate,
      ))
        CoupleDefaultCalendarEventOccurrence(
          kind: CoupleDefaultCalendarEventKind.relationshipAnniversary,
          label: anniversary.label,
          date: anniversary.date,
        ),
      for (final birthday in _sortedBirthdays(birthdays))
        if (_occursOnDate(birthday.birthDate, normalizedDate))
          CoupleDefaultCalendarEventOccurrence(
            kind: CoupleDefaultCalendarEventKind.birthday,
            label: _birthdayLabel(birthday.role),
            date: normalizedDate,
          ),
    ];
    return List.unmodifiable(occurrences);
  }

  Iterable<CoupleMemberBirthday> _sortedBirthdays(
    Iterable<CoupleMemberBirthday> birthdays,
  ) {
    final sorted = birthdays.toList(growable: false)
      ..sort((left, right) => left.role.index.compareTo(right.role.index));
    return sorted;
  }

  bool _occursOnDate(DateTime birthDate, DateTime date) {
    final occurrenceDay =
        birthDate.month == DateTime.february &&
            birthDate.day == 29 &&
            !_isLeapYear(date.year)
        ? 28
        : birthDate.day;
    return birthDate.month == date.month && occurrenceDay == date.day;
  }

  String _birthdayLabel(CoupleMemberRole role) {
    return switch (role) {
      CoupleMemberRole.self => '내 생일',
      CoupleMemberRole.partner => '상대방 생일',
    };
  }

  bool _isLeapYear(int year) {
    return year % 400 == 0 || (year % 4 == 0 && year % 100 != 0);
  }
}
