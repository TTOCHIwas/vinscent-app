import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/story_loops/application/today_story_loop_summary_provider.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';
import 'package:vinscent/features/story_loops/data/today_story_loop_summary_state.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';

void main() {
  test('does not fetch summary when readable couple is unavailable', () async {
    final repository = FakeStoryLoopReadRepository(
      todaySummary: sampleTodaySummary(),
    );
    final container = _container(
      couple: pendingCouple(),
      repository: repository,
    );
    addTearDown(container.dispose);

    final state = await container.read(todayStoryLoopSummaryProvider.future);

    expect(state, isA<UnavailableTodayStoryLoopSummaryState>());
    expect(repository.todaySummaryCallCount, 0);
  });

  test('returns empty state when repository returns no today summary row', () async {
    final repository = FakeStoryLoopReadRepository(todaySummary: null);
    final container = _container(
      couple: activeCouple(currentDate: DateTime(2026, 7, 6)),
      repository: repository,
    );
    addTearDown(container.dispose);

    final state = await container.read(todayStoryLoopSummaryProvider.future);

    expect(state, isA<EmptyTodayStoryLoopSummaryState>());
    final emptyState = state as EmptyTodayStoryLoopSummaryState;
    expect(emptyState.summary.isEmpty, isTrue);
    expect(emptyState.summary.canEditStory, isTrue);
    expect(repository.todaySummaryCallCount, 1);
  });

  test('returns loaded state when today summary exists', () async {
    final repository = FakeStoryLoopReadRepository(
      todaySummary: sampleTodaySummary(),
    );
    final container = _container(
      couple: activeCouple(currentDate: DateTime(2026, 7, 6)),
      repository: repository,
    );
    addTearDown(container.dispose);

    final state = await container.read(todayStoryLoopSummaryProvider.future);

    expect(state, isA<LoadedTodayStoryLoopSummaryState>());
    final loadedState = state as LoadedTodayStoryLoopSummaryState;
    expect(loadedState.summary.cardCount, 2);
    expect(loadedState.summary.question, isNotNull);
    expect(repository.todaySummaryCallCount, 1);
  });
}

ProviderContainer _container({
  required Couple? couple,
  required StoryLoopReadRepository repository,
}) {
  return ProviderContainer(
    overrides: [
      coupleControllerProvider.overrideWithBuild(
        (ref, notifier) async => couple,
      ),
      storyLoopReadRepositoryProvider.overrideWithValue(repository),
    ],
  );
}
