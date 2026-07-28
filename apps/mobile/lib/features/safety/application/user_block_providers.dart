import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_block.dart';
import '../data/user_block_repository.dart';
import 'user_safety_realtime_controller.dart';

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>((
  ref,
) async {
  ref.watch(userSafetyRevisionProvider);
  return ref.watch(userBlockRepositoryProvider).fetchBlockedUsers();
});

final reconnectableCoupleArchivesProvider =
    FutureProvider.autoDispose<List<ReconnectableCoupleArchive>>((ref) async {
      ref.watch(userSafetyRevisionProvider);
      return ref
          .watch(userBlockRepositoryProvider)
          .fetchReconnectableArchives();
    });
