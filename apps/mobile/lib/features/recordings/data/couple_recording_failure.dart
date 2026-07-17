enum CoupleRecordingFailureReason {
  configMissing,
  requestTimeout,
  authRequired,
  activeCoupleRequired,
  readableCoupleRequired,
  invalidRecordingId,
  invalidRecordingDuration,
  invalidRecordingPath,
  recordingFileMissing,
  currentRecordingRequired,
  invalidRecordingSlot,
  invalidRecordingSlotIndex,
  invalidRecordingSlotTitle,
  recordingSlotLocked,
  recordingSlotConflict,
  recordingSlotLimitReached,
  invalidRecordingArtwork,
  recordingArtworkFileMissing,
  recordingArtworkRequired,
  invalidRecordingPlacement,
  recordingPlacementConflict,
  recordingPlacementLimitReached,
  storage,
  unknown,
}

class CoupleRecordingRepositoryException implements Exception {
  const CoupleRecordingRepositoryException(this.reason, [this.message]);

  final CoupleRecordingFailureReason reason;
  final String? message;

  @override
  String toString() {
    final detail = message;
    if (detail == null || detail.isEmpty) {
      return 'CoupleRecordingRepositoryException($reason)';
    }

    return 'CoupleRecordingRepositoryException($reason, $detail)';
  }
}
