import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_event_date_picker_sheet.dart';

void main() {
  testWidgets('shows weekday context and returns the selected date', (
    tester,
  ) async {
    DateTime? selectedDate;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selectedDate = await showCalendarEventDatePickerSheet(
                  context: context,
                  initialDate: DateTime(2026, 8, 2),
                  minDate: DateTime(2026, 5, 1),
                  maxDate: DateTime(2026, 10, 31),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-event-date-picker-sheet')),
      findsOneWidget,
    );
    expect(find.text('2026년 8월'), findsOneWidget);
    for (final weekday in const ['일', '월', '화', '수', '목', '금', '토']) {
      expect(find.text(weekday), findsOneWidget);
    }
    final selectedDateMarker = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('calendar-event-date-2026-08-02')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (selectedDateMarker.decoration as BoxDecoration).color,
      AppColors.actionPrimary,
    );

    await tester.tap(find.byKey(const Key('calendar-event-date-2026-08-12')));
    await tester.tap(
      find.byKey(const Key('calendar-event-date-picker-complete')),
    );
    await tester.pumpAndSettle();

    expect(selectedDate, DateTime(2026, 8, 12));
  });

  testWidgets('moves one month by controls and horizontal swipe', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarEventDatePickerSheet(
            initialDate: DateTime(2026, 8, 2),
            minDate: DateTime(2026, 7, 1),
            maxDate: DateTime(2026, 10, 31),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('calendar-event-date-picker-next-month')),
    );
    await tester.pumpAndSettle();
    expect(find.text('2026년 9월'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('calendar-event-date-picker-swipe-region')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('2026년 8월'), findsOneWidget);
  });

  testWidgets('disables dates outside the selectable range', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarEventDatePickerSheet(
            initialDate: DateTime(2026, 8, 12),
            minDate: DateTime(2026, 8, 10),
            maxDate: DateTime(2026, 8, 20),
          ),
        ),
      ),
    );

    final beforeRange = tester.widget<InkWell>(
      find.byKey(const Key('calendar-event-date-2026-08-05')),
    );
    final inRange = tester.widget<InkWell>(
      find.byKey(const Key('calendar-event-date-2026-08-15')),
    );

    expect(beforeRange.onTap, isNull);
    expect(inRange.onTap, isNotNull);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('calendar-event-date-picker-previous-month')),
          )
          .onPressed,
      isNull,
    );
  });
}
