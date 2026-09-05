import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/couple_recording.dart';
import '../data/couple_recording_attention_repository.dart';
import '../recording_debug_log.dart';
import 'couple_recording_overview_controller.dart';

final recordingAttentionControllerProvider =
    Provider<RecordingAttentionController>((ref) {
      return RecordingAttentionController(
        repository: ref.watch(coupleRecordingAttentionRepositoryProvider),
        refreshOverview: () => ref
            .read(coupleRecordingOverviewControllerProvider.notifier)
            .refresh(),
      );
    });

class RecordingAttentionController {
  const RecordingAttentionController({
    required CoupleRecordingAttentionRepository repository,
    required Future<void> Function() refreshOverview,
  }) : _repository = repository,
       _refreshOverview = refreshOverview;

  final CoupleRecordingAttentionRepository _repository;
  final Future<void> Function() _refreshOverview;

  Future<void> acknowledgeCurrentRecording(
    CurrentCoupleRecording recording,
  ) async {
    if (!recording.isUnseen) {
      return;
    }

    try {
      final acknowledged = await _repository.acknowledgeCurrentRecording(
        recordingId: recording.recordingId,
      );
      if (acknowledged) {
        await _refreshOverview();
      }
    } catch (error) {
      debugRecordingLog(
        'Current recording acknowledgement failed: '
        'recordingId=${recording.recordingId}, error=$error',
      );
    }
  }

  Future<void> acknowledgeSlotRecording(CoupleRecordingSlot slot) async {
    if (!slot.isUnseen) {
      return;
    }

    try {
      final acknowledged = await _repository.acknowledgeSlotRecording(
        slotId: slot.slotId,
        recordingId: slot.recordingId,
      );
      if (acknowledged) {
        await _refreshOverview();
      }
    } catch (error) {
      debugRecordingLog(
        'Slot recording acknowledgement failed: '
        'slotId=${slot.slotId}, recordingId=${slot.recordingId}, error=$error',
      );
    }
  }
}
