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
