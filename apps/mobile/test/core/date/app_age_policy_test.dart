import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/app_age_policy.dart';

void main() {
  group('meetsMinimumServiceAge', () {
    test('accepts a user on their fourteenth birthday', () {
      expect(
        meetsMinimumServiceAge(
          birthDate: DateTime(2012, 7, 30),
          onDate: DateTime(2026, 7, 30),
        ),
        isTrue,
      );
    });

    test('rejects a user before their fourteenth birthday', () {
      expect(
        meetsMinimumServiceAge(
          birthDate: DateTime(2012, 7, 31),
          onDate: DateTime(2026, 7, 30),
        ),
        isFalse,
      );
    });

    test('rejects future birth dates', () {
      expect(
        meetsMinimumServiceAge(
          birthDate: DateTime(2026, 7, 31),
          onDate: DateTime(2026, 7, 30),
        ),
        isFalse,
      );
    });

    test('treats a leap-day birthday as March 1 in non-leap years', () {
      expect(
        meetsMinimumServiceAge(
          birthDate: DateTime(2012, 2, 29),
          onDate: DateTime(2026, 2, 28),
        ),
        isFalse,
      );
      expect(
        meetsMinimumServiceAge(
          birthDate: DateTime(2012, 2, 29),
          onDate: DateTime(2026, 3),
        ),
        isTrue,
      );
    });

    test('compares calendar dates without time-of-day differences', () {
      expect(
        meetsMinimumServiceAge(
          birthDate: DateTime(2012, 7, 30, 23, 59),
          onDate: DateTime(2026, 7, 30),
        ),
        isTrue,
      );
    });
  });
}
