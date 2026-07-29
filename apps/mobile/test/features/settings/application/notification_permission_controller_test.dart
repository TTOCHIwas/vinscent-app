import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/notifications/data/notification_permission_repository.dart';
import 'package:vinscent/features/notifications/data/push_token_repository.dart';
import 'package:vinscent/features/settings/application/notification_permission_controller.dart';

void main() {
  test('기기의 현재 알림 권한 상태를 불러온다', () async {
    final permissionRepository = _FakeNotificationPermissionRepository(
      status: NotificationPermissionStatus.denied,
    );
    final container = _container(permissionRepository: permissionRepository);
    addTearDown(container.dispose);

    final status = await container.read(
      notificationPermissionControllerProvider.future,
    );

    expect(status, NotificationPermissionStatus.denied);
    expect(permissionRepository.fetchCount, 1);
  });

  test('알림 권한을 허용하면 현재 기기 토큰을 등록한다', () async {
    final permissionRepository = _FakeNotificationPermissionRepository(
      status: NotificationPermissionStatus.notDetermined,
      requestedStatus: NotificationPermissionStatus.enabled,
    );
    final pushTokenRepository = _FakePushTokenRepository();
    final container = _container(
      permissionRepository: permissionRepository,
      pushTokenRepository: pushTokenRepository,
    );
    addTearDown(container.dispose);

    await container.read(notificationPermissionControllerProvider.future);
    await container
        .read(notificationPermissionControllerProvider.notifier)
        .requestPermission();

    expect(
      container.read(notificationPermissionControllerProvider).value,
      NotificationPermissionStatus.enabled,
    );
    expect(permissionRepository.requestCount, 1);
    expect(pushTokenRepository.registerCurrentDeviceTokenCount, 1);
  });

  test('권한이 거부된 상태에서는 기기 알림 설정을 연다', () async {
    final permissionRepository = _FakeNotificationPermissionRepository(
      status: NotificationPermissionStatus.denied,
    );
    final container = _container(permissionRepository: permissionRepository);
    addTearDown(container.dispose);

    await container.read(notificationPermissionControllerProvider.future);
    await container
        .read(notificationPermissionControllerProvider.notifier)
        .openSettings();

    expect(permissionRepository.openSettingsCount, 1);
  });
}

ProviderContainer _container({
  required NotificationPermissionRepository permissionRepository,
  PushTokenRepository? pushTokenRepository,
}) {
  return ProviderContainer(
    overrides: [
      notificationPermissionRepositoryProvider.overrideWithValue(
        permissionRepository,
      ),
      pushTokenRepositoryProvider.overrideWithValue(
        pushTokenRepository ?? _FakePushTokenRepository(),
      ),
    ],
  );
}

class _FakeNotificationPermissionRepository
    implements NotificationPermissionRepository {
  _FakeNotificationPermissionRepository({
    required this.status,
    this.requestedStatus,
  });

  NotificationPermissionStatus status;
  final NotificationPermissionStatus? requestedStatus;
  int fetchCount = 0;
  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  Future<NotificationPermissionStatus> fetchStatus() async {
    fetchCount++;
    return status;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCount++;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    requestCount++;
    status = requestedStatus ?? status;
    return status;
  }
}

class _FakePushTokenRepository implements PushTokenRepository {
  int registerCurrentDeviceTokenCount = 0;

  @override
  Stream<Map<String, dynamic>> get notificationOpens => const Stream.empty();

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Future<void> configureForegroundNotifications() async {}

  @override
  Future<void> deactivateCurrentDeviceToken() async {}

  @override
  Future<Map<String, dynamic>?> initiallyOpenedNotification() async => null;

  @override
  Future<void> registerCurrentDeviceToken() async {
    registerCurrentDeviceTokenCount++;
  }

  @override
  Future<void> registerRefreshedTokenIfAuthorized(String token) async {}
}
