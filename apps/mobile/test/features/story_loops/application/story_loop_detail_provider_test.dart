import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/story_loops/application/story_loop_detail_provider.dart';
import 'package:vinscent/features/story_loops/data/story_loop_detail_state.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';

void main() {
  test('does not fetch detail before relationship start date', () async {
    final repository = FakeStoryLoopReadRepository(
      details: {
        DateTime(2026, 7, 6): sampleStoryLoopDetail(),
      },
    );
    final container = _container(
      couple: activeCouple(
        relationshipStartDate: DateTime(2026, 7, 5),
        currentDate: DateTime(2026, 7, 6),
      ),
      repository: repository,
    );
    addTearDown(container.dispose);

    final state = await container.read(
      storyLoopDetailProvider(DateTime(2026, 7, 4)).future,
    );

    expect(state, isA<UnavailableStoryLoopDetailState>());
    expect(
      (state as UnavailableStoryLoopDetailState).reason,
      StoryLoopDetailUnavailableReason.beforeRelationshipStartDate,
    );
    expect(repository.requestedDetailDates, isEmpty);
  });

  test('does not fetch future detail', () async {
    final repository = FakeStoryLoopReadRepository(
      details: {
        DateTime(2026, 7, 6): sampleStoryLoopDetail(),
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

    final state = await container.read(
      storyLoopDetailProvider(DateTime(2026, 7, 7)).future,
    );

    expect(state, isA<UnavailableStoryLoopDetailState>());
    expect(
      (state as UnavailableStoryLoopDetailState).reason,
      StoryLoopDetailUnavailableReason.futureDate,
    );
    expect(repository.requestedDetailDates, isEmpty);
  });

  test('returns empty state when repository returns no row', () async {
    final repository = FakeStoryLoopReadRepository(details: const {});
    final container = _container(
      couple: activeCouple(
        relationshipStartDate: DateTime(2026, 7, 1),
        currentDate: DateTime(2026, 7, 6),
      ),
      repository: repository,
    );
    addTearDown(container.dispose);

    final state = await container.read(
      storyLoopDetailProvider(DateTime(2026, 7, 6)).future,
    );

    expect(state, isA<EmptyStoryLoopDetailState>());
    final emptyState = state as EmptyStoryLoopDetailState;
    expect(emptyState.detail.isEmpty, isTrue);
    expect(emptyState.detail.canEditStory, isTrue);
    expect(repository.requestedDetailDates, [DateTime(2026, 7, 6)]);
  });

  test('returns loaded state when detail exists', () async {
    final repository = FakeStoryLoopReadRepository(
      details: {
        DateTime(2026, 7, 6): sampleStoryLoopDetail(),
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

    final state = await container.read(
      storyLoopDetailProvider(DateTime(2026, 7, 6)).future,
    );

    expect(state, isA<LoadedStoryLoopDetailState>());
    final loadedState = state as LoadedStoryLoopDetailState;
    expect(loadedState.detail.question, isNotNull);
    expect(loadedState.detail.cards.length, 2);
    expect(repository.requestedDetailDates, [DateTime(2026, 7, 6)]);
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
