import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/notifications/application/push_token_controller.dart';
import 'package:vinscent/features/notifications/data/push_token_repository.dart';

void main() {
  test('does not register push token before authentication', () async {
    final repository = _FakePushTokenRepository();
    addTearDown(repository.dispose);
    final container = _container(
      authStatus: AuthStatus.unauthenticated,
      repository: repository,
    );
    addTearDown(container.dispose);

    await container.read(pushTokenControllerProvider.future);

    expect(repository.calls, isEmpty);
  });

  test('registers current device token after authentication', () async {
    final repository = _FakePushTokenRepository();
    addTearDown(repository.dispose);
    final container = _container(
      authStatus: AuthStatus.authenticated,
      repository: repository,
    );
    addTearDown(container.dispose);

    await container.read(pushTokenControllerProvider.future);

    expect(repository.calls, [
      'configureForegroundNotifications',
      'registerCurrentDeviceToken',
    ]);
  });

  test('registers refreshed push token after authentication', () async {
    final repository = _FakePushTokenRepository();
    addTearDown(repository.dispose);
    final container = _container(
      authStatus: AuthStatus.authenticated,
      repository: repository,
    );
    addTearDown(container.dispose);

    await container.read(pushTokenControllerProvider.future);
    repository.emitTokenRefresh('refreshed-token');
    await Future<void>.delayed(Duration.zero);

    expect(repository.registeredTokens, ['refreshed-token']);
  });
}

ProviderContainer _container({
  required AuthStatus authStatus,
  required PushTokenRepository repository,
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWithBuild((ref, notifier) => authStatus),
      pushTokenRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

class _FakePushTokenRepository implements PushTokenRepository {
  final calls = <String>[];
  final registeredTokens = <String>[];
  final _tokenRefreshController = StreamController<String>.broadcast();

  @override
  Stream<String> get tokenRefreshes => _tokenRefreshController.stream;

  @override
  Future<void> configureForegroundNotifications() async {
    calls.add('configureForegroundNotifications');
  }

  @override
  Future<void> registerCurrentDeviceToken() async {
    calls.add('registerCurrentDeviceToken');
  }

  @override
  Future<void> deactivateCurrentDeviceToken() async {
    calls.add('deactivateCurrentDeviceToken');
  }

  @override
  Future<void> registerToken(String token) async {
    registeredTokens.add(token);
  }

  void emitTokenRefresh(String token) {
    _tokenRefreshController.add(token);
  }

  void dispose() {
    _tokenRefreshController.close();
  }
}
