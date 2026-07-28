import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../../couple/application/couple_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../data/user_safety_state_change_source.dart';

final userSafetyRevisionProvider = NotifierProvider<UserSafetyRevision, int>(
  UserSafetyRevision.new,
);

class UserSafetyRevision extends Notifier<int> {
  @override
  int build() => 0;

  void advance() {
    state += 1;
  }
}

final userSafetyRealtimeControllerProvider =
    AsyncNotifierProvider<UserSafetyRealtimeController, void>(
      UserSafetyRealtimeController.new,
      retry: (_, _) => null,
    );

class UserSafetyRealtimeController extends AsyncNotifier<void> {
  static const _refreshDebounce = Duration(milliseconds: 160);

  StreamSubscription<int>? _changesSubscription;
  Timer? _refreshTimer;
  Future<void>? _pendingSubscriptionCancellation;

  @override
  Future<void> build() async {
    _registerLifecycle();
    final authStatus = ref.watch(authControllerProvider);
    final profileFuture = authStatus == AuthStatus.authenticated
        ? ref.watch(profileControllerProvider.future)
        : null;

    await _stopWatchingChanges();
    if (!ref.mounted || authStatus != AuthStatus.authenticated) {
      return;
    }

    final profile = await profileFuture!;
    if (!ref.mounted || profile == null) {
      return;
    }

    _watchChanges(profile.id);
  }

  void refreshReadModels() {
    if (!ref.mounted) {
      return;
    }

    ref.read(userSafetyRevisionProvider.notifier).advance();
    unawaited(ref.read(coupleControllerProvider.notifier).refreshSilently());
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

  void _watchChanges(String userId) {
    _changesSubscription = ref
        .read(userSafetyStateChangeSourceProvider)
        .watch(userId: userId)
        .listen(
          (_) => _scheduleRefresh(),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('[safety] Realtime stream failed: $error');
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
    StreamSubscription<int>? subscription,
  ) async {
    if (subscription == null) {
      return;
    }
    try {
      await subscription.cancel();
    } catch (error) {
      debugPrint('[safety] Realtime cancellation failed: $error');
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
