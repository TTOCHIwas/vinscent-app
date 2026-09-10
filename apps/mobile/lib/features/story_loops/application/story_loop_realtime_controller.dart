import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../../couple/application/couple_controller.dart';
import '../data/story_loop_change_source.dart';
import '../story_loop_debug_log.dart';

final storyLoopReadRevisionProvider =
    NotifierProvider<StoryLoopReadRevision, int>(StoryLoopReadRevision.new);

final storyCardReadRevisionProvider =
    NotifierProvider<StoryLoopReadRevision, int>(StoryLoopReadRevision.new);

final dailyQuestionReadRevisionProvider =
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

  StreamSubscription<StoryLoopChangeKind>? _changesSubscription;
  Timer? _refreshTimer;
  Future<void>? _pendingSubscriptionCancellation;
  final Set<StoryLoopChangeKind> _pendingKinds = {};

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
    ref.read(storyCardReadRevisionProvider.notifier).advance();
    ref.read(dailyQuestionReadRevisionProvider.notifier).advance();
  }

  void _registerLifecycle() {
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _pendingKinds.clear();
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
          (kind) => _scheduleRefresh(kind),
          onError: (Object error, StackTrace stackTrace) {
            debugStoryLoopLog('Realtime stream failed: $error');
          },
        );
  }

  Future<void> _stopWatchingChanges() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _pendingKinds.clear();
    final pendingCancellation = _pendingSubscriptionCancellation;
    _pendingSubscriptionCancellation = null;
    await pendingCancellation;
    final subscription = _changesSubscription;
    _changesSubscription = null;
    await _cancelSubscription(subscription);
  }

  Future<void> _cancelSubscription(
    StreamSubscription<StoryLoopChangeKind>? subscription,
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

  void _scheduleRefresh(StoryLoopChangeKind kind) {
    _pendingKinds.add(kind);
    _refreshTimer?.cancel();
    _refreshTimer = Timer(_refreshDebounce, () {
      _refreshTimer = null;
      final kinds = Set<StoryLoopChangeKind>.from(_pendingKinds);
      _pendingKinds.clear();
      ref.read(storyLoopReadRevisionProvider.notifier).advance();
      if (kinds.contains(StoryLoopChangeKind.cards) ||
          kinds.contains(StoryLoopChangeKind.all)) {
        ref.read(storyCardReadRevisionProvider.notifier).advance();
      }
      if (kinds.contains(StoryLoopChangeKind.questions) ||
          kinds.contains(StoryLoopChangeKind.all)) {
        ref.read(dailyQuestionReadRevisionProvider.notifier).advance();
      }
    });
  }
}
