import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'push_token_failure.dart';

final pushTokenRepositoryProvider = Provider<PushTokenRepository>((ref) {
  return FirebasePushTokenRepository();
});

abstract interface class PushTokenRepository {
  Future<void> configureForegroundNotifications();

  Future<void> registerCurrentDeviceToken();

  Future<void> deactivateCurrentDeviceToken();

  Stream<String> get tokenRefreshes;

  Future<void> registerToken(String token);
}

class FirebasePushTokenRepository implements PushTokenRepository {
  FirebasePushTokenRepository({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'couple_expression_notifications',
    '표현 알림',
    description: '상대방이 보낸 표현 알림입니다.',
    importance: Importance.high,
  );

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  bool _foregroundNotificationsConfigured = false;

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Future<void> configureForegroundNotifications() async {
    if (_foregroundNotificationsConfigured || !_isPushPlatformSupported) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initializationSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(initializationSettings);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);

      FirebaseMessaging.onMessage.listen(_showForegroundAndroidNotification);
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _foregroundNotificationsConfigured = true;
  }

  @override
  Future<void> registerCurrentDeviceToken() async {
    _ensureSupabaseConfigured();

    if (!_isPushPlatformSupported) {
      throw const PushTokenRepositoryException(
        PushTokenFailureReason.unsupportedPlatform,
      );
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await registerToken(token);
  }

  @override
  Future<void> deactivateCurrentDeviceToken() async {
    if (!AppConfig.isSupabaseConfigured || !_isPushPlatformSupported) {
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await Supabase.instance.client
          .rpc('deactivate_user_push_token', params: {'push_token': token})
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const PushTokenRepositoryException(
        PushTokenFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<void> registerToken(String token) async {
    _ensureSupabaseConfigured();

    if (!_isPushPlatformSupported) {
      throw const PushTokenRepositoryException(
        PushTokenFailureReason.unsupportedPlatform,
      );
    }

    try {
      await Supabase.instance.client
          .rpc(
            'upsert_user_push_token',
            params: {'push_token': token, 'push_platform': _currentPlatform},
          )
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const PushTokenRepositoryException(
        PushTokenFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  Future<void> _showForegroundAndroidNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  void _ensureSupabaseConfigured() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const PushTokenRepositoryException(
        PushTokenFailureReason.configMissing,
      );
    }
  }

  bool get _isPushPlatformSupported {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get _currentPlatform {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => throw const PushTokenRepositoryException(
        PushTokenFailureReason.unsupportedPlatform,
      ),
    };
  }

  PushTokenRepositoryException _mapPostgrestError(PostgrestException error) {
    return PushTokenRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  PushTokenFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => PushTokenFailureReason.authRequired,
      'invalid_push_token' => PushTokenFailureReason.invalidPushToken,
      'invalid_push_platform' => PushTokenFailureReason.invalidPushPlatform,
      _ => PushTokenFailureReason.unknown,
    };
  }
}
