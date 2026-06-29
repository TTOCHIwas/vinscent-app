import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/data/couple_recording_failure.dart';
import 'package:vinscent/features/recordings/data/recording_upload_failure_policy.dart';

void main() {
  group('shouldDiscardUploadedRecording', () {
    test('returns true for recording file missing', () {
      const error = CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.recordingFileMissing,
      );

      expect(shouldDiscardUploadedRecording(error), isTrue);
    });

    test('returns true for invalid recording path', () {
      const error = CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.invalidRecordingPath,
      );

      expect(shouldDiscardUploadedRecording(error), isTrue);
    });

    test('returns false for request timeout', () {
      const error = CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );

      expect(shouldDiscardUploadedRecording(error), isFalse);
    });

    test('returns false for unknown failure', () {
      const error = CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.unknown,
      );

      expect(shouldDiscardUploadedRecording(error), isFalse);
    });
  });
}
