import 'dart:typed_data';

import '../../couple/data/couple.dart';
import 'pending_recording_draft_policy.dart';
import 'pending_recording_draft_store.dart';

typedef PendingRecordingUploader =
    Future<void> Function({
      required Couple couple,
      required PendingRecordingDraft draft,
      required Uint8List audioBytes,
    });

enum PendingRecordingUploadOutcome { uploaded, retained, discarded }

class PendingRecordingUploadResult {
  const PendingRecordingUploadResult({required this.outcome, this.error});

  final PendingRecordingUploadOutcome outcome;
  final Object? error;
}

class PendingRecordingUploadCoordinator {
  PendingRecordingUploadCoordinator({
    required PendingRecordingDraftStore store,
    required PendingRecordingUploader uploader,
  }) : _store = store,
       _uploader = uploader;

  final PendingRecordingDraftStore _store;
  final PendingRecordingUploader _uploader;
  Future<PendingRecordingUploadResult>? _activeUpload;

  Future<String> createFilePath(String recordingId) {
    return _store.createFilePath(recordingId);
  }

  Future<void> persist(PendingRecordingDraft draft) {
    return _store.persist(draft);
  }

  Future<PendingRecordingDraft?> load() {
    return _store.load();
  }

  Future<void> discard(PendingRecordingDraft draft) {
    return _store.remove(draft);
  }

  Future<PendingRecordingUploadResult> upload({
    required Couple couple,
    required PendingRecordingDraft draft,
  }) {
    final activeUpload = _activeUpload;
    if (activeUpload != null) {
      return activeUpload;
    }

    final upload = _performUpload(couple: couple, draft: draft);
    _activeUpload = upload;
    upload.whenComplete(() {
      if (identical(_activeUpload, upload)) {
        _activeUpload = null;
      }
    });
    return upload;
  }

  Future<PendingRecordingUploadResult> _performUpload({
    required Couple couple,
    required PendingRecordingDraft draft,
  }) async {
    try {
      final audioBytes = await _store.readAudioBytes(draft);
      for (var attempt = 0; attempt < 2; attempt += 1) {
        try {
          await _uploader(couple: couple, draft: draft, audioBytes: audioBytes);
          break;
        } catch (error) {
          if (attempt == 1 || !shouldRetainPendingRecordingDraft(error)) {
            rethrow;
          }
        }
      }

      await _store.remove(draft);
      return const PendingRecordingUploadResult(
        outcome: PendingRecordingUploadOutcome.uploaded,
      );
    } catch (error) {
      if (shouldRetainPendingRecordingDraft(error)) {
        return PendingRecordingUploadResult(
          outcome: PendingRecordingUploadOutcome.retained,
          error: error,
        );
      }

      try {
        await _store.remove(draft);
      } catch (_) {}
      return PendingRecordingUploadResult(
        outcome: PendingRecordingUploadOutcome.discarded,
        error: error,
      );
    }
  }
}
