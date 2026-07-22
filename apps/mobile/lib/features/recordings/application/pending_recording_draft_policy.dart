import '../data/couple_recording_failure.dart';

bool shouldRetainPendingRecordingDraft(Object error) {
  if (error is! CoupleRecordingRepositoryException) {
    return true;
  }

  return switch (error.reason) {
    CoupleRecordingFailureReason.requestTimeout ||
    CoupleRecordingFailureReason.authRequired ||
    CoupleRecordingFailureReason.storage ||
    CoupleRecordingFailureReason.unknown => true,
    _ => false,
  };
}
