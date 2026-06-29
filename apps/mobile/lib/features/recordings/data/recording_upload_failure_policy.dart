import 'couple_recording_failure.dart';

bool shouldDiscardUploadedRecording(
  CoupleRecordingRepositoryException error,
) {
  return switch (error.reason) {
    CoupleRecordingFailureReason.recordingFileMissing ||
    CoupleRecordingFailureReason.invalidRecordingPath => true,
    _ => false,
  };
}
