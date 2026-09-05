import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/application/recording_attention_controller.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
import 'package:vinscent/features/recordings/data/couple_recording_attention_repository.dart';

void main() {
  group('RecordingAttentionController', () {
    test(
      'refreshes the overview only after an exact current acknowledgement',
      () async {
        final repository = _FakeAttentionRepository(currentResult: true);
        var refreshCount = 0;
        final controller = RecordingAttentionController(
          repository: repository,
          refreshOverview: () async => refreshCount += 1,
        );

        await controller.acknowledgeCurrentRecording(_current(isUnseen: true));

        expect(repository.currentRecordingIds, ['current-1']);
        expect(refreshCount, 1);
      },
    );

    test(
      'keeps attention when the server rejects a stale slot revision',
      () async {
        final repository = _FakeAttentionRepository(slotResult: false);
        var refreshCount = 0;
        final controller = RecordingAttentionController(
          repository: repository,
          refreshOverview: () async => refreshCount += 1,
        );

        await controller.acknowledgeSlotRecording(_slot(isUnseen: true));

        expect(repository.slotRequests, [('slot-1', 'recording-1')]);
        expect(refreshCount, 0);
      },
    );

    test('does not write a receipt for an already seen recording', () async {
      final repository = _FakeAttentionRepository();
      final controller = RecordingAttentionController(
        repository: repository,
        refreshOverview: () async {},
      );

      await controller.acknowledgeCurrentRecording(_current(isUnseen: false));
      await controller.acknowledgeSlotRecording(_slot(isUnseen: false));

      expect(repository.currentRecordingIds, isEmpty);
      expect(repository.slotRequests, isEmpty);
    });
  });
}

class _FakeAttentionRepository implements CoupleRecordingAttentionRepository {
  _FakeAttentionRepository({
    this.currentResult = false,
    this.slotResult = false,
  });

  final bool currentResult;
  final bool slotResult;
  final currentRecordingIds = <String>[];
  final slotRequests = <(String, String)>[];

  @override
  Future<bool> acknowledgeCurrentRecording({
    required String recordingId,
  }) async {
    currentRecordingIds.add(recordingId);
    return currentResult;
  }

  @override
  Future<bool> acknowledgeSlotRecording({
    required String slotId,
    required String recordingId,
  }) async {
    slotRequests.add((slotId, recordingId));
    return slotResult;
  }
}

CurrentCoupleRecording _current({required bool isUnseen}) {
  final timestamp = DateTime.utc(2026, 9, 5);
  return CurrentCoupleRecording(
    recordingId: 'current-1',
    senderUserId: 'partner',
    durationMs: 1000,
    recordedAt: timestamp,
    revision: 1,
    updatedAt: timestamp,
    audioUrl: 'https://example.com/current.m4a',
    isUnseen: isUnseen,
  );
}

CoupleRecordingSlot _slot({required bool isUnseen}) {
  final timestamp = DateTime.utc(2026, 9, 5);
  return CoupleRecordingSlot(
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
    isUnseen: isUnseen,
  );
}
