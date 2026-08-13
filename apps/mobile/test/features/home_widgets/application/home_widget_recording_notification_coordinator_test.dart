import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_recording_notification_coordinator.dart';

void main() {
  test('marks the required recording before starting targeted sync', () async {
    final events = <String>[];
    final coordinator = HomeWidgetRecordingNotificationCoordinator(
      markRequired: ({required coupleId, required recordingId}) async {
        events.add('mark:$coupleId:$recordingId');
      },
      synchronizeRecording: ({required expectedCoupleId}) async {
        events.add('sync:$expectedCoupleId');
      },
    );

    final handled = await coordinator.handle({
      'type': 'recording_activity',
      'event_type': 'current_recording_updated',
      'couple_id': 'couple-id',
      'recording_id': 'recording-id',
    });

    expect(handled, isTrue);
    expect(events, [
      'mark:couple-id:recording-id',
      'sync:couple-id',
    ]);
  });

  test('ignores recording slot notifications and incomplete payloads', () async {
    var callCount = 0;
    final coordinator = HomeWidgetRecordingNotificationCoordinator(
      markRequired: ({required coupleId, required recordingId}) async {
        callCount += 1;
      },
      synchronizeRecording: ({required expectedCoupleId}) async {
        callCount += 1;
      },
    );

    expect(
      await coordinator.handle({
        'type': 'recording_activity',
        'event_type': 'slot_saved',
        'couple_id': 'couple-id',
        'recording_id': 'recording-id',
      }),
      isFalse,
    );
    expect(
      await coordinator.handle({
        'type': 'recording_activity',
        'event_type': 'current_recording_updated',
        'couple_id': 'couple-id',
      }),
      isFalse,
    );
    expect(callCount, 0);
  });
}
