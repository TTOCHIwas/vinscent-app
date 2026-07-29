import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../../couple/application/couple_controller.dart';
import '../data/couple_calendar_event_change_source.dart';

final coupleCalendarEventRevisionProvider =
    NotifierProvider<CoupleCalendarEventRevision, int>(
      CoupleCalendarEventRevision.new,
    );

class CoupleCalendarEventRevision extends Notifier<int> {
  @override
  int build() => 0;

  void advance() {
    state += 1;
  }
}

final coupleCalendarEventRealtimeControllerProvider =
    AsyncNotifierProvider<CoupleCalendarEventRealtimeController, void>(
      CoupleCalendarEventRealtimeController.new,
      retry: (_, _) => null,
    );

class CoupleCalendarEventRealtimeController extends AsyncNotifier<void> {
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
    if (ref.mounted) {
      ref.read(coupleCalendarEventRevisionProvider.notifier).advance();
    }
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
        .read(coupleCalendarEventChangeSourceProvider)
        .watch(coupleId: coupleId)
        .listen(
          (_) => _scheduleRefresh(),
          onError: (Object error, StackTrace stackTrace) {
            if (kDebugMode) {
              debugPrint('[calendar] Realtime stream failed: $error');
            }
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
      if (kDebugMode) {
        debugPrint('[calendar] Realtime cancellation failed: $error');
      }
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
