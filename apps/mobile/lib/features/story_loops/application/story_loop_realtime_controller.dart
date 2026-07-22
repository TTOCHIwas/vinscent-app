import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../../couple/application/couple_controller.dart';
import '../data/story_loop_change_source.dart';
import '../story_loop_debug_log.dart';

final storyLoopReadRevisionProvider =
    NotifierProvider<StoryLoopReadRevision, int>(StoryLoopReadRevision.new);

class StoryLoopReadRevision extends Notifier<int> {
  @override
  int build() => 0;

  void advance() {
    state += 1;
  }
}

final storyLoopRealtimeControllerProvider =
    AsyncNotifierProvider<StoryLoopRealtimeController, void>(
      StoryLoopRealtimeController.new,
      retry: (_, _) => null,
    );

class StoryLoopRealtimeController extends AsyncNotifier<void> {
  static const _refreshDebounce = Duration(milliseconds: 160);

  StreamSubscription<void>? _changesSubscription;
  Timer? _refreshTimer;
  Future<void>? _pendingSubscriptionCancellation;

  @override
  Future<void> build() async {
    _registerLifecycle();
    final authStatus = ref.watch(authControllerProvider);
    final coupleFuture = authStatus == AuthStatus.authenticated
        ? ref.watch(coupleControllerProvider.future)
        : null;

    await _stopWatchingChanges();
    if (!ref.mounted || authStatus != AuthStatus.authenticated) {
      return;
    }

    final couple = await coupleFuture!;
    if (!ref.mounted || couple == null || !couple.canReadSharedData) {
      return;
    }

    _watchChanges(couple.id);
  }

  void refreshReadModels() {
    if (!ref.mounted) {
      return;
    }
    ref.read(storyLoopReadRevisionProvider.notifier).advance();
  }

  void _registerLifecycle() {
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      final subscription = _changesSubscription;
      _changesSubscription = null;
      _pendingSubscriptionCancellation = _cancelSubscription(subscription);
    });
  }

  void _watchChanges(String coupleId) {
    _changesSubscription = ref
        .read(storyLoopChangeSourceProvider)
        .watch(coupleId: coupleId)
        .listen(
          (_) => _scheduleRefresh(),
          onError: (Object error, StackTrace stackTrace) {
            debugStoryLoopLog('Realtime stream failed: $error');
          },
        );
  }

  Future<void> _stopWatchingChanges() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    final pendingCancellation = _pendingSubscriptionCancellation;
    _pendingSubscriptionCancellation = null;
    await pendingCancellation;
    final subscription = _changesSubscription;
    _changesSubscription = null;
    await _cancelSubscription(subscription);
  }

  Future<void> _cancelSubscription(
    StreamSubscription<void>? subscription,
  ) async {
    if (subscription == null) {
      return;
    }
    try {
      await subscription.cancel();
    } catch (error) {
      debugStoryLoopLog('Realtime cancellation failed: $error');
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(_refreshDebounce, () {
      _refreshTimer = null;
      refreshReadModels();
    });
  }
}
