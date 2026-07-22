import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/story_loops/application/story_loop_detail_provider.dart';
import 'package:vinscent/features/story_loops/application/story_loop_month_summary_provider.dart';
import 'package:vinscent/features/story_loops/application/story_loop_realtime_controller.dart';
import 'package:vinscent/features/story_loops/application/today_story_loop_summary_provider.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';

void main() {
  test('refreshes every active story loop read model when revision changes', () async {
    final date = DateTime(2026, 7, 6);
    final month = DateTime(2026, 7);
    final repository = FakeStoryLoopReadRepository(
      todaySummary: sampleTodaySummary(),
      details: {date: sampleStoryLoopDetail()},
      monthSummaries: {
        month: [sampleMonthSummaryDay()],
      },
    );
    final container = ProviderContainer(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(currentDate: date),
        ),
        storyLoopReadRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final todaySubscription = container.listen(
      todayStoryLoopSummaryProvider,
      (_, _) {},
    );
    final detailSubscription = container.listen(
      storyLoopDetailProvider(date),
      (_, _) {},
    );
    final monthSubscription = container.listen(
      storyLoopMonthSummaryProvider(month),
      (_, _) {},
    );
    addTearDown(todaySubscription.close);
    addTearDown(detailSubscription.close);
    addTearDown(monthSubscription.close);

    await Future.wait([
      container.read(todayStoryLoopSummaryProvider.future),
      container.read(storyLoopDetailProvider(date).future),
      container.read(storyLoopMonthSummaryProvider(month).future),
    ]);

    container.read(storyLoopReadRevisionProvider.notifier).advance();

    await _waitUntil(
      () =>
          repository.todaySummaryCallCount == 2 &&
          repository.requestedDetailDates.length == 2 &&
          repository.requestedMonths.length == 2,
    );
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(timeoutAt)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}
