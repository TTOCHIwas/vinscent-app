import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/story_loops/application/story_loop_detail_navigation_provider.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  test('builds previous and next dates within relationship range', () async {
    final container = ProviderContainer(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(
            relationshipStartDate: DateTime(2026, 7, 1),
            currentDate: DateTime(2026, 7, 6),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(
      storyLoopDetailNavigationProvider(DateTime(2026, 7, 5)).future,
    );

    expect(state.currentDate, DateTime(2026, 7, 5));
    expect(state.previousDate, DateTime(2026, 7, 4));
    expect(state.nextDate, DateTime(2026, 7, 6));
  });

  test('returns current date only when requested date is out of range', () async {
    final container = ProviderContainer(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(
            relationshipStartDate: DateTime(2026, 7, 1),
            currentDate: DateTime(2026, 7, 6),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(
      storyLoopDetailNavigationProvider(DateTime(2026, 7, 7)).future,
    );

    expect(state.currentDate, DateTime(2026, 7, 7));
    expect(state.previousDate, isNull);
    expect(state.nextDate, isNull);
  });
}
