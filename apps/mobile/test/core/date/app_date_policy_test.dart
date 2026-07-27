import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/app_date_policy.dart';

void main() {
  group('currentAppDate', () {
    test('keeps the same date before KST midnight', () {
      final date = currentAppDate(now: DateTime.utc(2026, 5, 30, 14, 59));

      expect(date, DateTime(2026, 5, 30));
    });

    test('moves to the next date at KST midnight', () {
      final date = currentAppDate(now: DateTime.utc(2026, 5, 30, 15));

      expect(date, DateTime(2026, 5, 31));
    });
  });

  group('calendarDateOnly', () {
    test('removes time fields', () {
      final date = calendarDateOnly(DateTime(2026, 5, 31, 23, 59, 58));

      expect(date, DateTime(2026, 5, 31));
    });
  });

  test('normalizes and compares calendar months', () {
    final month = calendarMonthOnly(DateTime(2026, 5, 31, 23, 59));

    expect(month, DateTime(2026, 5));
    expect(isSameCalendarMonth(month, DateTime(2026, 5, 15)), isTrue);
    expect(isSameCalendarMonth(month, DateTime(2026, 6)), isFalse);
  });

  test('compares and formats calendar dates without time fields', () {
    final date = DateTime(2026, 5, 3, 23, 59);

    expect(isSameCalendarDate(date, DateTime(2026, 5, 3)), isTrue);
    expect(isSameCalendarDate(date, DateTime(2026, 5, 4)), isFalse);
    expect(formatCalendarDate(date), '2026-05-03');
  });

  group('parseCalendarDate', () {
    test('parses a strict calendar route date', () {
      expect(parseCalendarDate('2026-07-27'), DateTime(2026, 7, 27));
    });

    test('rejects malformed and impossible dates', () {
      expect(parseCalendarDate('2026-7-27'), isNull);
      expect(parseCalendarDate('2026-02-30'), isNull);
      expect(parseCalendarDate(null), isNull);
    });
  });

  group('durationUntilNextAppDate', () {
    test('returns the duration until the next KST midnight', () {
      final duration = durationUntilNextAppDate(
        now: DateTime.utc(2026, 5, 30, 14, 30),
      );

      expect(duration, const Duration(minutes: 30));
    });

    test('returns a full day at exact KST midnight', () {
      final duration = durationUntilNextAppDate(
        now: DateTime.utc(2026, 5, 30, 15),
      );

      expect(duration, const Duration(days: 1));
    });
  });
}
