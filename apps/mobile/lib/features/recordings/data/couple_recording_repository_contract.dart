import 'dart:typed_data';

import 'couple_recording.dart';

abstract interface class CoupleRecordingRepository {
  Future<CoupleRecordingOverview> fetchOverview();

  Future<void> uploadCurrentRecording({
    required String coupleId,
    required Uint8List audioBytes,
    required int durationMs,
    String? recordingId,
    bool resumeExistingUpload = false,
  });

  Future<CoupleRecordingSlotSaveResult> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  });

  Future<void> deleteSlot({
    required String slotId,
    required int expectedSlotRevision,
  });

  Future<void> openNextSlot();

  Future<Uint8List> fetchSlotArtworkDrawingData({
    required String drawingDataPath,
  });

  Future<void> saveSlotArtwork({
    required String coupleId,
    required String slotId,
    required int expectedSlotRevision,
    required Uint8List previewBytes,
    required Uint8List drawingDataBytes,
  });

  Future<void> upsertSlotPlacement({
    required String slotId,
    required double normalizedX,
    required double normalizedY,
    required int? expectedPlacementRevision,
  });

  Future<void> deleteSlotPlacement({
    required String slotId,
    required int expectedPlacementRevision,
  });
}
