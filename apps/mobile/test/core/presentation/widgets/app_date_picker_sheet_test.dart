import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_date_picker_sheet.dart';

void main() {
  testWidgets('clamps the initial date to the selectable range', (
    tester,
  ) async {
    DateTime? selectedDate;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selectedDate = await showAppDatePickerSheet(
                  context: context,
                  title: '날짜 선택',
                  initialDate: DateTime(2030, 1, 1),
                  minDate: DateTime(1900, 1, 1),
                  maxDate: DateTime(2026, 7, 28),
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
    expect(find.byKey(const Key('app-date-picker-sheet')), findsOneWidget);
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(selectedDate, DateTime(2026, 7, 28));
  });

  testWidgets('renders the shared sheet title and three date columns', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDatePickerSheet(
            title: '생일 선택',
            initialDate: DateTime(2000, 5, 10),
            minDate: DateTime(1900, 1, 1),
            maxDate: DateTime(2026, 7, 28),
          ),
        ),
      ),
    );

    expect(find.text('생일 선택'), findsOneWidget);
    expect(find.byKey(const Key('app-date-picker-year')), findsOneWidget);
    expect(find.byKey(const Key('app-date-picker-month')), findsOneWidget);
    expect(find.byKey(const Key('app-date-picker-day')), findsOneWidget);
  });
}
