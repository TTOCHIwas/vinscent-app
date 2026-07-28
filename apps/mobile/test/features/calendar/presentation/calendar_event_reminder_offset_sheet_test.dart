import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_event_reminder_offset_sheet.dart';

void main() {
  testWidgets('returns the selected reminder offset from a bottom sheet', (
    tester,
  ) async {
    int? selectedOffset;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selectedOffset = await showCalendarEventReminderOffsetSheet(
                  context: context,
                  selectedOffsetDays: 0,
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
      find.byKey(const Key('calendar-event-reminder-offset-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-event-reminder-offset-0')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('calendar-event-reminder-offset-7')));
    await tester.pumpAndSettle();

    expect(selectedOffset, 7);
  });
}
