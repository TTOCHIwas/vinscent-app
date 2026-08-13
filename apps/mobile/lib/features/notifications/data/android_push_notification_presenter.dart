import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const androidPushNotificationChannel = AndroidNotificationChannel(
  'vinscent_notifications',
  '커플 알림',
  description: '질문, 스토리, 음성, 연결 상태 알림을 표시합니다.',
  importance: Importance.high,
);

class AndroidPushNotificationContent {
  const AndroidPushNotificationContent({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

AndroidPushNotificationContent? resolveAndroidPushNotificationContent({
  required String? notificationTitle,
  required String? notificationBody,
  required Map<String, dynamic> data,
}) {
  final title =
      _nonEmpty(notificationTitle) ?? _nonEmpty(data['notification_title']);
  final body =
      _nonEmpty(notificationBody) ?? _nonEmpty(data['notification_body']);
  if (title == null || body == null) {
    return null;
  }
  return AndroidPushNotificationContent(title: title, body: body);
}

class AndroidPushNotificationPresenter {
  const AndroidPushNotificationPresenter({
    required FlutterLocalNotificationsPlugin localNotifications,
  }) : _localNotifications = localNotifications;

  final FlutterLocalNotificationsPlugin _localNotifications;

  Future<void> configure({
    DidReceiveNotificationResponseCallback? onNotificationResponse,
  }) async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_widget_notification'),
    );
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onNotificationResponse,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidPushNotificationChannel);
  }

  Future<bool> show(RemoteMessage message) async {
    final content = resolveAndroidPushNotificationContent(
      notificationTitle: message.notification?.title,
      notificationBody: message.notification?.body,
      data: message.data,
    );
    if (content == null) {
      return false;
    }

    final notificationId =
        message.messageId?.hashCode ??
        message.data['event_id']?.hashCode ??
        message.data.hashCode;
    await _localNotifications.show(
      notificationId,
      content.title,
      content.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          androidPushNotificationChannel.id,
          androidPushNotificationChannel.name,
          channelDescription: androidPushNotificationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
    return true;
  }
}

String? _nonEmpty(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
