import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home/application/day_count.dart';

void main() {
  test('returns one on the relationship start date', () {
    final count = calculateRelationshipDayCount(
      startDate: DateTime(2026, 5, 31),
      today: DateTime(2026, 5, 31),
    );

    expect(count, 1);
  });

  test('returns two on the next day', () {
    final count = calculateRelationshipDayCount(
      startDate: DateTime(2026, 5, 31),
      today: DateTime(2026, 6, 1),
    );

    expect(count, 2);
  });

  test('includes the first day in long ranges', () {
    final count = calculateRelationshipDayCount(
      startDate: DateTime(2026, 5, 1),
      today: DateTime(2026, 5, 11),
    );

    expect(count, 11);
  });

  test('ignores time of day', () {
    final count = calculateRelationshipDayCount(
      startDate: DateTime(2026, 5, 31, 23, 59),
      today: DateTime(2026, 6, 1, 0, 1),
    );

    expect(count, 2);
  });

  test('clamps future start dates to one', () {
    final count = calculateRelationshipDayCount(
      startDate: DateTime(2026, 6, 1),
      today: DateTime(2026, 5, 31),
    );

    expect(count, 1);
  });
}
