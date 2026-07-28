import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_time_picker_sheet.dart';

void main() {
  testWidgets('returns the initial time when the sheet is completed', (
    tester,
  ) async {
    TimeOfDay? selectedTime;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selectedTime = await showAppTimePickerSheet(
                  context: context,
                  title: '알림 시간',
                  initialTime: const TimeOfDay(hour: 9, minute: 30),
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

    expect(find.byKey(const Key('app-time-picker-sheet')), findsOneWidget);
    expect(find.byKey(const Key('app-time-picker-wheel')), findsOneWidget);

    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(selectedTime, const TimeOfDay(hour: 9, minute: 30));
  });
}
