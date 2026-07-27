import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationPermissionRepositoryProvider =
    Provider<NotificationPermissionRepository>(
      (ref) => FirebaseNotificationPermissionRepository(),
    );

enum NotificationPermissionStatus {
  enabled,
  denied,
  notDetermined,
  unsupported;

  bool get canReceiveNotifications => this == enabled;
}

abstract interface class NotificationPermissionRepository {
  Future<NotificationPermissionStatus> fetchStatus();

  Future<NotificationPermissionStatus> requestPermission();

  Future<void> openSettings();
}

class FirebaseNotificationPermissionRepository
    implements NotificationPermissionRepository {
  FirebaseNotificationPermissionRepository({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<NotificationPermissionStatus> fetchStatus() async {
    if (!_isSupportedPlatform) {
      return NotificationPermissionStatus.unsupported;
    }

    final settings = await _messaging.getNotificationSettings();
    return _mapStatus(settings.authorizationStatus);
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    if (!_isSupportedPlatform) {
      return NotificationPermissionStatus.unsupported;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return _mapStatus(settings.authorizationStatus);
  }

  @override
  Future<void> openSettings() async {
    if (!_isSupportedPlatform) {
      return;
    }

    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  NotificationPermissionStatus _mapStatus(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => NotificationPermissionStatus.enabled,
      AuthorizationStatus.denied => NotificationPermissionStatus.denied,
      AuthorizationStatus.notDetermined =>
        NotificationPermissionStatus.notDetermined,
    };
  }
}
