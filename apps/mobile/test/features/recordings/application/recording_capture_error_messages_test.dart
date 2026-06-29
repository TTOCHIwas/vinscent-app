import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/application/recording_capture_error_messages.dart';
import 'package:vinscent/features/recordings/data/couple_recording_failure.dart';

void main() {
  group('recordingCaptureErrorMessage', () {
    test('maps recording file missing to retry guidance', () {
      const error = CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.recordingFileMissing,
      );

      expect(
        recordingCaptureErrorMessage(error),
        '저장을 완료하지 못했어요. 다시 시도해 주세요.',
      );
    });

    test('maps request timeout to upload delay guidance', () {
      const error = CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );

      expect(
        recordingCaptureErrorMessage(error),
        '녹음 업로드가 지연되고 있어요. 다시 시도해 주세요.',
      );
    });

    test('maps storage failures to file save error message', () {
      const error = CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.storage,
      );

      expect(
        recordingCaptureErrorMessage(error),
        '녹음 파일을 저장하지 못했어요.',
      );
    });

    test('falls back to generic message for unknown errors', () {
      expect(
        recordingCaptureErrorMessage(Exception('boom')),
        '녹음을 저장하지 못했어요.',
      );
    });
  });
}
