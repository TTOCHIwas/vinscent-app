import 'dart:typed_data';

import 'couple_recording.dart';

abstract interface class CoupleRecordingOverviewReader {
  Future<CoupleRecordingOverview> fetchOverview();
}

abstract interface class CurrentCoupleRecordingWriter {
  Future<void> uploadCurrentRecording({
    required String coupleId,
    required Uint8List audioBytes,
    required int durationMs,
    String? recordingId,
    bool resumeExistingUpload = false,
  });
}

abstract interface class CoupleRecordingSlotWriter {
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
}

abstract interface class CoupleRecordingSlotArtworkStore {
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
}

abstract interface class CoupleRecordingSlotPlacementStore {
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
