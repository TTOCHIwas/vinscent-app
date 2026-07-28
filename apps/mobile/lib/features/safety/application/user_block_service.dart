import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../couple/application/couple_controller.dart';
import '../data/user_block_repository.dart';
import 'user_safety_realtime_controller.dart';

final userBlockServiceProvider = Provider<UserBlockService>(
  UserBlockService.new,
);

class UserBlockService {
  const UserBlockService(this._ref);

  final Ref _ref;

  Future<void> blockCurrentPartner() async {
    await _ref.read(userBlockRepositoryProvider).blockCurrentPartner();
    await _refreshSafetyBoundary();
  }

  Future<bool> unblockUser(String userId) async {
    final wasUnblocked = await _ref
        .read(userBlockRepositoryProvider)
        .unblockUser(userId);
    if (wasUnblocked) {
      await _refreshSafetyBoundary();
    }
    return wasUnblocked;
  }

  Future<void> createReconnectInvite(String coupleId) async {
    await _ref
        .read(userBlockRepositoryProvider)
        .createReconnectInvite(coupleId);
    await _refreshSafetyBoundary();
  }

  Future<void> _refreshSafetyBoundary() async {
    _ref.read(userSafetyRevisionProvider.notifier).advance();
    await _ref.read(coupleControllerProvider.notifier).refreshSilently();
  }
}
