import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/data/notification_permission_repository.dart';
import '../../notifications/data/push_token_repository.dart';

final notificationPermissionControllerProvider =
    AsyncNotifierProvider<
      NotificationPermissionController,
      NotificationPermissionStatus
    >(NotificationPermissionController.new);

class NotificationPermissionController
    extends AsyncNotifier<NotificationPermissionStatus> {
  @override
  Future<NotificationPermissionStatus> build() {
    return ref.watch(notificationPermissionRepositoryProvider).fetchStatus();
  }

  Future<void> refresh() async {
    try {
      final status = await ref
          .read(notificationPermissionRepositoryProvider)
          .fetchStatus();
      state = AsyncValue.data(status);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> requestPermission() async {
    final status = await ref
        .read(notificationPermissionRepositoryProvider)
        .requestPermission();
    state = AsyncValue.data(status);
    await _reconcileCurrentDeviceToken();
  }

  Future<void> openSettings() {
    return ref.read(notificationPermissionRepositoryProvider).openSettings();
  }

  Future<void> _reconcileCurrentDeviceToken() async {
    try {
      await ref.read(pushTokenRepositoryProvider).reconcileCurrentDeviceToken();
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[push] Token reconciliation after permission update failed: $error',
        );
      }
    }
  }
}
