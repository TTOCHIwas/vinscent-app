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
    await ref.read(coupleRepositoryProvider).cancelInvite();
    state = const AsyncValue.data(null);
  }

  Future<Couple> updateRelationshipStartDate(DateTime date) async {
    final couple = await ref
        .read(coupleRepositoryProvider)
        .updateRelationshipStartDate(date);
    state = AsyncValue.data(couple);
    return couple;
  }
}
