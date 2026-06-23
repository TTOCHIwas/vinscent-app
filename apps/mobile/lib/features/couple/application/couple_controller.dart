import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../../profile/application/profile_controller.dart';
import '../data/couple.dart';
import '../data/couple_repository.dart';

final coupleControllerProvider =
    AsyncNotifierProvider<CoupleController, Couple?>(CoupleController.new);

class CoupleController extends AsyncNotifier<Couple?> {
  @override
  Future<Couple?> build() async {
    final authStatus = ref.watch(authControllerProvider);
    if (authStatus != AuthStatus.authenticated) {
      return null;
    }

    final profile = await ref.watch(profileControllerProvider.future);
    if (profile == null) {
      return null;
    }

    return ref.watch(coupleRepositoryProvider).fetchCurrentCouple();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(coupleRepositoryProvider).fetchCurrentCouple(),
    );
  }

  Future<Couple> createInvite() async {
    final couple = await ref.read(coupleRepositoryProvider).createInvite();
    state = AsyncValue.data(couple);
    return couple;
  }

  Future<Couple> joinByCode(String inviteCode) async {
    final couple = await ref
        .read(coupleRepositoryProvider)
        .joinByCode(inviteCode);
    state = AsyncValue.data(couple);
    return couple;
  }

  Future<void> cancelInvite() async {
    final couple = await ref.read(coupleRepositoryProvider).cancelInvite();
    state = AsyncValue.data(couple);
  }

  Future<Couple> updateRelationshipStartDate(DateTime date) async {
    final couple = await ref
        .read(coupleRepositoryProvider)
        .updateRelationshipStartDate(date);
    state = AsyncValue.data(couple);
    return couple;
  }

  Future<Couple> disconnectCouple() async {
    final couple = await ref.read(coupleRepositoryProvider).disconnectCouple();
    state = AsyncValue.data(couple);
    return couple;
  }

  Future<void> deleteDisconnectedArchiveNow() async {
    await ref.read(coupleRepositoryProvider).deleteDisconnectedArchiveNow();
    state = const AsyncValue.data(null);
  }
}
