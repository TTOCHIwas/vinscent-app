import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/notifications/data/android_push_notification_presenter.dart';

void main() {
  test('prefers visible FCM notification content', () {
    final content = resolveAndroidPushNotificationContent(
      notificationTitle: '기존 제목',
      notificationBody: '기존 본문',
      data: const {
        'notification_title': '데이터 제목',
        'notification_body': '데이터 본문',
      },
    );

    expect(content?.title, '기존 제목');
    expect(content?.body, '기존 본문');
  });

  test('uses data content for a background recording message', () {
    final content = resolveAndroidPushNotificationContent(
      notificationTitle: null,
      notificationBody: null,
      data: const {
        'notification_title': '단짠',
        'notification_body': '새 녹음이 도착했어요',
      },
    );

    expect(content?.title, '단짠');
    expect(content?.body, '새 녹음이 도착했어요');
  });

  test('rejects incomplete notification content', () {
    expect(
      resolveAndroidPushNotificationContent(
        notificationTitle: null,
        notificationBody: null,
        data: const {'notification_title': '단짠'},
      ),
      isNull,
    );
  });
}
