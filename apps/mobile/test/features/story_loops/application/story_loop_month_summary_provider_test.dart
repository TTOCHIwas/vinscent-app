import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/story_loops/application/story_loop_month_summary_provider.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';

void main() {
  test('does not fetch month summary when readable couple is unavailable', () async {
    final repository = FakeStoryLoopReadRepository(
      monthSummaries: {
        DateTime(2026, 7): [sampleMonthSummaryDay()],
      },
    );
    final container = _container(
      couple: pendingCouple(),
      repository: repository,
    );
    addTearDown(container.dispose);

    final result = await container.read(
      storyLoopMonthSummaryProvider(DateTime(2026, 7, 1)).future,
    );

    expect(result, isEmpty);
    expect(repository.requestedMonths, isEmpty);
  });

  test('does not fetch month summary outside relationship range', () async {
    final repository = FakeStoryLoopReadRepository(
      monthSummaries: {
        DateTime(2026, 7): [sampleMonthSummaryDay()],
      },
    );
    final container = _container(
      couple: activeCouple(
        relationshipStartDate: DateTime(2026, 7, 1),
        currentDate: DateTime(2026, 7, 6),
      ),
      repository: repository,
    );
    addTearDown(container.dispose);

    final result = await container.read(
      storyLoopMonthSummaryProvider(DateTime(2026, 6, 1)).future,
    );

    expect(result, isEmpty);
    expect(repository.requestedMonths, isEmpty);
  });

  test('fetches month summary within readable range', () async {
    final repository = FakeStoryLoopReadRepository(
      monthSummaries: {
        DateTime(2026, 7): [sampleMonthSummaryDay()],
      },
    );
    final container = _container(
      couple: activeCouple(
        relationshipStartDate: DateTime(2026, 7, 1),
        currentDate: DateTime(2026, 7, 6),
      ),
      repository: repository,
    );
    addTearDown(container.dispose);

    final result = await container.read(
      storyLoopMonthSummaryProvider(DateTime(2026, 7, 15)).future,
    );

    expect(result.length, 1);
    expect(result.first.cardCount, 1);
    expect(repository.requestedMonths, [DateTime(2026, 7)]);
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
