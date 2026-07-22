import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/application/pending_recording_draft_policy.dart';
import 'package:vinscent/features/recordings/data/couple_recording_failure.dart';

void main() {
  test('retains drafts for transient repository failures', () {
    expect(
      shouldRetainPendingRecordingDraft(
        const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.requestTimeout,
        ),
      ),
      isTrue,
    );
    expect(
      shouldRetainPendingRecordingDraft(
        const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.storage,
        ),
      ),
      isTrue,
    );
  });

  test('discards drafts rejected by the recording write contract', () {
    expect(
      shouldRetainPendingRecordingDraft(
        const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.invalidRecordingPath,
        ),
      ),
      isFalse,
    );
    expect(
      shouldRetainPendingRecordingDraft(
        const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.recordingFileMissing,
        ),
      ),
      isFalse,
    );
  });

  test('retains drafts for unexpected failures', () {
    expect(shouldRetainPendingRecordingDraft(Exception('offline')), isTrue);
  });
}
