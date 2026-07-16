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
    'vinscent_notifications',
    '커플 알림',
    description: '질문, 스토리, 녹음, 연결 상태 알림을 표시합니다.',
    importance: Importance.high,
  );

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  bool _foregroundNotificationsConfigured = false;

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Future<void> configureForegroundNotifications() async {
    if (_foregroundNotificationsConfigured) {
      _debugPushLog('Foreground notifications skipped: already configured');
      return;
    }

    if (!_isPushPlatformSupported) {
      _debugPushLog('Foreground notifications skipped: unsupported platform');
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      _debugPushLog('Android foreground notification channel setup started');
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
      _debugPushLog('Android foreground notification channel setup completed');
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _debugPushLog('iOS foreground notification presentation setup started');
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _debugPushLog('iOS foreground notification presentation setup completed');
    }

    _foregroundNotificationsConfigured = true;
  }

  @override
  Future<void> registerCurrentDeviceToken() async {
    _debugPushLog('Current device token registration requested');
    _ensureSupabaseConfigured();

    if (!_isPushPlatformSupported) {
      _debugPushLog(
        'Current device token registration failed: unsupported platform',
      );
      throw const PushTokenRepositoryException(
        PushTokenFailureReason.unsupportedPlatform,
      );
    }

    _debugPushLog('FCM notification permission request started');
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _debugPushLog(
      'FCM notification permission result: ${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _debugPushLog(
        'Current device token registration skipped: permission denied',
      );
      return;
    }

    _debugPushLog('FCM token request started');
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      _debugPushLog(
        'Current device token registration skipped: FCM token is empty',
      );
      return;
    }

    _debugPushLog(
      'FCM token received: prefix=${_tokenPrefix(token)}, '
      'length=${token.length}',
    );
    await registerToken(token);
  }

  @override
  Future<void> deactivateCurrentDeviceToken() async {
    if (!AppConfig.isSupabaseConfigured || !_isPushPlatformSupported) {
      _debugPushLog(
        'Token deactivation skipped: app is not configured for push',
      );
      return;
    }

    _debugPushLog('Current device token deactivation requested');
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      _debugPushLog('Token deactivation skipped: FCM token is empty');
      return;
    }

    try {
      _debugPushLog(
        'deactivate_user_push_token RPC started: '
        'prefix=${_tokenPrefix(token)}, length=${token.length}',
      );
      await Supabase.instance.client
          .rpc('deactivate_user_push_token', params: {'push_token': token})
          .timeout(AppConfig.supabaseRpcTimeout);
      _debugPushLog('deactivate_user_push_token RPC completed');
    } on TimeoutException {
      _debugPushLog('deactivate_user_push_token RPC failed: timeout');
      throw const PushTokenRepositoryException(
        PushTokenFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      _debugPushLog('deactivate_user_push_token RPC failed: ${error.message}');
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<void> registerToken(String token) async {
    _ensureSupabaseConfigured();

    if (!_isPushPlatformSupported) {
      _debugPushLog('upsert_user_push_token RPC skipped: unsupported platform');
      throw const PushTokenRepositoryException(
        PushTokenFailureReason.unsupportedPlatform,
      );
    }

    final platform = _currentPlatform;
    _debugPushLog(
      'upsert_user_push_token RPC requested: '
      'platform=$platform, prefix=${_tokenPrefix(token)}, '
      'length=${token.length}',
    );

    try {
      await Supabase.instance.client
          .rpc(
            'upsert_user_push_token',
            params: {'push_token': token, 'push_platform': platform},
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      _debugPushLog('upsert_user_push_token RPC completed');
    } on TimeoutException {
      _debugPushLog('upsert_user_push_token RPC failed: timeout');
      throw const PushTokenRepositoryException(
        PushTokenFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      _debugPushLog('upsert_user_push_token RPC failed: ${error.message}');
      throw _mapPostgrestError(error);
    }
  }

  Future<void> _showForegroundAndroidNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      _debugPushLog('Foreground FCM message received without notification');
      return;
    }

    _debugPushLog(
      'Foreground FCM notification received: ${notification.title}',
    );
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
      _debugPushLog('Supabase configuration missing');
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

  String _tokenPrefix(String token) {
    if (token.length <= 12) {
      return token;
    }

    return token.substring(0, 12);
  }

  void _debugPushLog(String message) {
    if (kDebugMode) {
      debugPrint('[push] $message');
    }
  }
}
