import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/notifications/application/push_notification_route.dart';

void main() {
  group('resolvePushNotificationLocation', () {
    test('uses an allow-listed explicit route', () {
      final location = resolvePushNotificationLocation({
        'type': 'ai_update',
        'route': '/ai',
      });

      expect(location, '/ai');
    });

    test('does not navigate to an external explicit route', () {
      final location = resolvePushNotificationLocation({
        'type': 'partner_story_card_uploaded',
        'route': 'https://example.com',
      });

      expect(location, '/home');
    });

    test('opens the dated question for an answer notification', () {
      final location = resolvePushNotificationLocation({
        'type': 'partner_answer_completed',
        'assigned_date': '2026-07-21',
      });

      expect(location, '/home/question?date=2026-07-21');
    });

    test('opens the recording library for slot activity', () {
      final location = resolvePushNotificationLocation({
        'type': 'recording_activity',
        'event_type': 'slot_saved',
      });

      expect(location, '/home/recordings');
    });

    test('opens the current recording on home', () {
      final location = resolvePushNotificationLocation({
        'type': 'recording_activity',
        'event_type': 'current_recording_updated',
      });

      expect(location, '/home');
    });

    test('opens AI review for a memory review event', () {
      final location = resolvePushNotificationLocation({
        'type': 'ai_update',
        'event_type': 'ai_memory_review_ready',
      });

      expect(location, '/ai');
    });

    test('opens AI for asynchronous AI result events', () {
      for (final eventType in [
        'ai_direct_answer_ready',
        'ai_direct_answer_failed',
        'ai_focused_partner_waiting',
      ]) {
        final location = resolvePushNotificationLocation({
          'type': 'ai_update',
          'event_type': eventType,
        });

        expect(location, '/ai');
      }
    });

    test('opens the dated question for an AI feedback event', () {
      final location = resolvePushNotificationLocation({
        'type': 'ai_update',
        'event_type': 'ai_feedback_ready',
        'assigned_date': '2026-07-20',
      });

      expect(location, '/home/question?date=2026-07-20');
    });

    test('opens the calendar date for a calendar event reminder', () {
      final location = resolvePushNotificationLocation({
        'type': 'calendar_event_reminder',
        'event_date': '2026-07-26',
        'route': '/calendar?date=2026-07-26',
      });

      expect(location, '/calendar?date=2026-07-26');
    });

    test('falls back to the calendar when a reminder date is invalid', () {
      final location = resolvePushNotificationLocation({
        'type': 'calendar_event_reminder',
        'event_date': 'not-a-date',
      });

      expect(location, '/calendar');
    });

    test('returns null for an unknown notification', () {
      expect(resolvePushNotificationLocation({'type': 'unknown'}), isNull);
    });
  });
}
