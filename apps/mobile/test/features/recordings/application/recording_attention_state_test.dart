import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/application/recording_attention_state.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';

void main() {
  test(
    'aggregates current recording and slot attention without losing leaf ids',
    () {
      final timestamp = DateTime.utc(2026, 9, 5);
      final overview = CoupleRecordingOverview(
        slotLimit: 2,
        currentRecording: CurrentCoupleRecording(
          recordingId: 'current-1',
          senderUserId: 'partner',
          durationMs: 1000,
          recordedAt: timestamp,
          revision: 1,
          updatedAt: timestamp,
          audioUrl: 'https://example.com/current.m4a',
          isUnseen: true,
        ),
        savedSlots: [
          CoupleRecordingSlot(
            slotId: 'slot-1',
            slotIndex: 1,
            title: '첫 녹음',
            recordingId: 'recording-1',
            senderUserId: 'partner',
            durationMs: 1000,
            recordedAt: timestamp,
            slotRevision: 1,
            createdByUserId: 'partner',
            updatedByUserId: 'partner',
            createdAt: timestamp,
            updatedAt: timestamp,
            audioUrl: 'https://example.com/slot.m4a',
            isUnseen: true,
          ),
        ],
      );

      final state = RecordingAttentionState.fromOverview(overview);

      expect(state.hasUnseenCurrentRecording, isTrue);
      expect(state.unseenSlotIds, {'slot-1'});
      expect(state.hasUnread, isTrue);
    },
  );
}
