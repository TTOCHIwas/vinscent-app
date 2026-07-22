import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../../profile/application/profile_controller.dart';
import '../data/couple.dart';
import '../data/couple_change_source.dart';
import '../data/couple_failure.dart';
import '../data/couple_repository.dart';

final coupleControllerProvider =
    AsyncNotifierProvider<CoupleController, Couple?>(CoupleController.new);

class CoupleController extends AsyncNotifier<Couple?> {
  static const _realtimeRefreshDebounce = Duration(milliseconds: 160);

  StreamSubscription<void>? _coupleChangesSubscription;
  Timer? _realtimeRefreshTimer;
  String? _watchedCoupleId;

  @override
  Future<Couple?> build() async {
    ref.onDispose(() {
      _realtimeRefreshTimer?.cancel();
      unawaited(_coupleChangesSubscription?.cancel());
    });

    final authStatus = ref.watch(authControllerProvider);
    if (authStatus != AuthStatus.authenticated) {
      _watchCoupleChanges(null);
      return null;
    }

    final profile = await ref.watch(profileControllerProvider.future);
    if (profile == null) {
      _watchCoupleChanges(null);
      return null;
    }

    final couple = await ref
        .watch(coupleRepositoryProvider)
        .fetchCurrentCouple();
    _watchCoupleChanges(couple?.id);
    return couple;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final nextState = await AsyncValue.guard(
      () => ref.read(coupleRepositoryProvider).fetchCurrentCouple(),
    );
    state = nextState;
    if (nextState case AsyncData<Couple?>(:final value)) {
      _watchCoupleChanges(value?.id);
    }
  }

  Future<Couple> createInvite() async {
    final couple = await ref.read(coupleRepositoryProvider).createInvite();
    _setCouple(couple);
    return couple;
  }

  Future<Couple> joinByCode(String inviteCode) async {
    final couple = await ref
        .read(coupleRepositoryProvider)
        .joinByCode(inviteCode);
    _setCouple(couple);
    return couple;
  }

  Future<void> cancelInvite() async {
    final couple = await ref.read(coupleRepositoryProvider).cancelInvite();
    _setCouple(couple);
  }

  Future<Couple> updateRelationshipStartDate(DateTime date) async {
    final couple = await ref
        .read(coupleRepositoryProvider)
        .updateRelationshipStartDate(date);
    _setCouple(couple);
    return couple;
  }

  Future<Couple> useDefaultCharacter() async {
    final couple = await ref
        .read(coupleRepositoryProvider)
        .useDefaultCharacter();
    _setCouple(couple);
    return couple;
  }

  Future<Couple> disconnectCouple() async {
    final couple = await ref.read(coupleRepositoryProvider).disconnectCouple();
    _setCouple(couple);
    return couple;
  }

  Future<void> deleteDisconnectedArchiveNow() async {
    try {
      await ref.read(coupleRepositoryProvider).deleteDisconnectedArchiveNow();
    } on CoupleRepositoryException catch (error) {
      if (error.reason != CoupleFailureReason.archivedCoupleRequired) {
        rethrow;
      }
    }
    _setCouple(null);
  }

  void _setCouple(Couple? couple) {
    state = AsyncValue.data(couple);
    _watchCoupleChanges(couple?.id);
  }

  void _watchCoupleChanges(String? coupleId) {
    if (_watchedCoupleId == coupleId) {
      return;
    }

    _watchedCoupleId = coupleId;
    unawaited(_coupleChangesSubscription?.cancel());
    _coupleChangesSubscription = null;
    if (coupleId == null) {
      return;
    }

    _coupleChangesSubscription = ref
        .read(coupleChangeSourceProvider)
        .watch(coupleId: coupleId)
        .listen((_) {
          _realtimeRefreshTimer?.cancel();
          _realtimeRefreshTimer = Timer(
            _realtimeRefreshDebounce,
            _refreshFromRealtime,
          );
        });
  }

  void _refreshFromRealtime() {
    _realtimeRefreshTimer = null;
    unawaited(_performRealtimeRefresh());
  }

  Future<void> _performRealtimeRefresh() async {
    try {
      final couple = await ref
          .read(coupleRepositoryProvider)
          .fetchCurrentCouple();
      if (!ref.mounted) {
        return;
      }

      _setCouple(couple);
    } catch (_) {
      // Keep the last usable state; later realtime or lifecycle refresh recovers.
    }
  }
}
