import '../../../core/date/app_date_policy.dart';

enum CoupleAnniversaryKind {
  yearly,
  hundredDays,
  firstDay,
  tenDays,
  twentyTwoDays,
  fiftyDays,
}

class CoupleAnniversaryOccurrence {
  const CoupleAnniversaryOccurrence({
    required this.kind,
    required this.label,
    required this.date,
  });

  final CoupleAnniversaryKind kind;
  final String label;
  final DateTime date;
}

class CoupleAnniversaryResolver {
  const CoupleAnniversaryResolver();

  List<CoupleAnniversaryOccurrence> resolve({
    required DateTime startDate,
    required DateTime date,
  }) {
    final normalizedStart = calendarDateOnly(startDate);
    final normalizedDate = calendarDateOnly(date);
    if (normalizedDate.isBefore(normalizedStart)) {
      return const [];
    }

    final occurrences = <CoupleAnniversaryOccurrence>[
      ..._resolveYearly(normalizedStart, normalizedDate),
      ..._resolveDayMilestone(normalizedStart, normalizedDate),
    ];
    return List.unmodifiable(occurrences);
  }

  Iterable<CoupleAnniversaryOccurrence> _resolveYearly(
    DateTime startDate,
    DateTime date,
  ) sync* {
    final elapsedYears = date.year - startDate.year;
    if (elapsedYears < 1) {
      return;
    }

    final anniversaryDate = _anniversaryDate(startDate, date.year);
    if (isSameCalendarDate(date, anniversaryDate)) {
      yield CoupleAnniversaryOccurrence(
        kind: CoupleAnniversaryKind.yearly,
        label: '$elapsedYears주년',
        date: date,
      );
    }
  }

  Iterable<CoupleAnniversaryOccurrence> _resolveDayMilestone(
    DateTime startDate,
    DateTime date,
  ) sync* {
    final dayCount = date.difference(startDate).inDays + 1;
    final milestone = switch (dayCount) {
      1 => (CoupleAnniversaryKind.firstDay, '첫날'),
      10 => (CoupleAnniversaryKind.tenDays, '10일'),
      22 => (CoupleAnniversaryKind.twentyTwoDays, '22일'),
      50 => (CoupleAnniversaryKind.fiftyDays, '50일'),
      >= 100 when dayCount % 100 == 0 => (
        CoupleAnniversaryKind.hundredDays,
        '$dayCount일',
      ),
      _ => null,
    };

    if (milestone != null) {
      yield CoupleAnniversaryOccurrence(
        kind: milestone.$1,
        label: milestone.$2,
        date: date,
      );
    }
  }

  DateTime _anniversaryDate(DateTime startDate, int year) {
    if (startDate.month == DateTime.february &&
        startDate.day == 29 &&
        !_isLeapYear(year)) {
      return DateTime(year, DateTime.february, 28);
    }
    return DateTime(year, startDate.month, startDate.day);
  }

  bool _isLeapYear(int year) {
    return year % 400 == 0 || (year % 4 == 0 && year % 100 != 0);
  }
}
