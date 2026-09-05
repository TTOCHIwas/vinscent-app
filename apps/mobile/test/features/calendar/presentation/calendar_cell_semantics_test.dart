import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/story_loop_fixtures.dart';
import 'calendar_screen_test_support.dart';

void main() {
  testWidgets('announces the card count in a calendar date cell', (
    tester,
  ) async {
    final date = DateTime(2026, 5, 10);
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(
        monthSummaries: {
          DateTime(2026, 5): [
            sampleMonthSummaryDay(
              coupleDate: date,
              cardCount: 2,
              cards: [
                samplePreviewCard(id: 'card-a'),
                samplePreviewCard(id: 'card-b'),
              ],
            ),
          ],
        },
      ),
    );

    final cellSemantics = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.label?.startsWith('10일') == true,
    );

    expect(cellSemantics, findsOneWidget);
    final semantics = tester.widget<Semantics>(cellSemantics);
    expect(semantics.properties.label, contains('카드 2개'));
  });

  testWidgets(
    'announces and marks the current day independently of selection',
    (tester) async {
      await pumpCalendar(
        tester,
        repository: FakeStoryLoopReadRepository(),
        today: DateTime(2026, 5, 10),
        initialDate: DateTime(2026, 5, 5),
      );

      final todaySemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.contains('오늘') == true,
      );

      expect(todaySemantics, findsOneWidget);
      expect(
        find.byKey(const ValueKey('calendar-today-indicator-2026-05-10')),
        findsOneWidget,
      );
    },
  );
}
