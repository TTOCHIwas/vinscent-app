import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/presentation/calendar_date_navigation.dart';

void main() {
  const navigation = CalendarDateNavigation();
  final relationshipStartDate = DateTime(2026, 1, 10);

  test('preserves and clamps the selected day when moving by month', () {
    expect(
      navigation.moveByMonth(
        selectedDate: DateTime(2026, 1, 31),
        monthOffset: 1,
        relationshipStartDate: relationshipStartDate,
      ),
      DateTime(2026, 2, 28),
    );
  });

  test('keeps the selected weekday when moving by week', () {
    final selectedDate = DateTime(2026, 7, 8);
    final target = navigation.moveByWeek(
      selectedDate: selectedDate,
      weekOffset: 1,
      relationshipStartDate: relationshipStartDate,
    );

    expect(target, DateTime(2026, 7, 15));
    expect(target?.weekday, selectedDate.weekday);
  });

  test('blocks a week that would cross before the relationship start', () {
    expect(
      navigation.moveByWeek(
        selectedDate: DateTime(2026, 1, 12),
        weekOffset: -1,
        relationshipStartDate: relationshipStartDate,
      ),
      isNull,
    );
  });

  test('clamps a start-month selection to the relationship start date', () {
    expect(
      navigation.moveByMonth(
        selectedDate: DateTime(2026, 2, 5),
        monthOffset: -1,
        relationshipStartDate: relationshipStartDate,
      ),
      relationshipStartDate,
    );
  });
}
