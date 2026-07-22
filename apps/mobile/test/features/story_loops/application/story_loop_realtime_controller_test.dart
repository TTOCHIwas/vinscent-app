import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/story_loops/application/story_loop_realtime_controller.dart';
import 'package:vinscent/features/story_loops/data/story_loop_change_source.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  test('coalesces a burst of story loop changes into one revision', () async {
    final changeSource = _FakeStoryLoopChangeSource();
    final container = _buildContainer(changeSource);
    addTearDown(container.dispose);

    await container.read(storyLoopRealtimeControllerProvider.future);
    expect(changeSource.watchedCoupleId, 'couple-id');
    expect(container.read(storyLoopReadRevisionProvider), 0);

    changeSource.emit();
    changeSource.emit();
    changeSource.emit();

    await _waitUntil(
      () => container.read(storyLoopReadRevisionProvider) == 1,
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(container.read(storyLoopReadRevisionProvider), 1);
  });

  test('manual refresh advances the story loop revision', () async {
    final changeSource = _FakeStoryLoopChangeSource();
    final container = _buildContainer(changeSource);
    addTearDown(container.dispose);

    await container.read(storyLoopRealtimeControllerProvider.future);

    container
        .read(storyLoopRealtimeControllerProvider.notifier)
        .refreshReadModels();

    expect(container.read(storyLoopReadRevisionProvider), 1);
  });

  test('replaces and disposes the realtime subscription on rebuild', () async {
    final changeSource = _FakeStoryLoopChangeSource();
    final container = _buildContainer(changeSource);

    await container.read(storyLoopRealtimeControllerProvider.future);
    container.invalidate(storyLoopRealtimeControllerProvider);
    await container.read(storyLoopRealtimeControllerProvider.future);

    expect(changeSource.watchCount, 2);
    expect(changeSource.cancelCount, 1);

    container.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(changeSource.cancelCount, 2);
  });
}

ProviderContainer _buildContainer(_FakeStoryLoopChangeSource changeSource) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWithBuild(
        (ref, notifier) => AuthStatus.authenticated,
      ),
      coupleControllerProvider.overrideWithBuild(
        (ref, notifier) async => activeCouple(),
      ),
      storyLoopChangeSourceProvider.overrideWithValue(changeSource),
    ],
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(timeoutAt)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}

class _FakeStoryLoopChangeSource implements StoryLoopChangeSource {
  final List<StreamController<void>> _controllers = [];
  String? watchedCoupleId;
  int watchCount = 0;
  int cancelCount = 0;

  void emit() {
    _controllers.last.add(null);
  }

  @override
  Stream<void> watch({required String coupleId}) {
    watchedCoupleId = coupleId;
    watchCount += 1;
    final controller = StreamController<void>(
      onCancel: () {
        cancelCount += 1;
      },
    );
    _controllers.add(controller);
    return controller.stream;
  }
}
