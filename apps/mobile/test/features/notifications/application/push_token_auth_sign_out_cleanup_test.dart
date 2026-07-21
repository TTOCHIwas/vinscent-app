import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/notifications/application/push_token_auth_sign_out_cleanup.dart';
import 'package:vinscent/features/notifications/data/push_token_repository.dart';

void main() {
  test('deactivates the current device token during auth cleanup', () async {
    final repository = _FakePushTokenRepository();
    final cleanup = PushTokenAuthSignOutCleanup(repository);

    await cleanup.run();

    expect(repository.deactivateCount, 1);
  });
}

class _FakePushTokenRepository implements PushTokenRepository {
  int deactivateCount = 0;

  @override
  Stream<Map<String, dynamic>> get notificationOpens => const Stream.empty();

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Future<void> configureForegroundNotifications() async {}

  @override
  Future<void> deactivateCurrentDeviceToken() async {
    deactivateCount += 1;
  }

  @override
  Future<Map<String, dynamic>?> initiallyOpenedNotification() async => null;

  @override
  Future<void> registerCurrentDeviceToken() async {}

  @override
  Future<void> registerToken(String token) async {}
}
