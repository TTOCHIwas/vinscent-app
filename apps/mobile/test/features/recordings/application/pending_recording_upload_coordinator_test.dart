import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/recordings/application/pending_recording_draft_store.dart';
import 'package:vinscent/features/recordings/application/pending_recording_upload_coordinator.dart';
import 'package:vinscent/features/recordings/data/couple_recording_failure.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  const draft = PendingRecordingDraft(
    recordingId: '30000000-0000-0000-0000-000000000001',
    coupleId: 'couple-id',
    durationMs: 1200,
  );

  test('uploads a persisted draft and removes it after success', () async {
    final store = _MemoryPendingRecordingDraftStore(draft: draft);
    final uploader = _FakePendingRecordingUploader();
    final coordinator = PendingRecordingUploadCoordinator(
      store: store,
      uploader: uploader.call,
    );

    final result = await coordinator.upload(
      couple: activeCouple(),
      draft: draft,
    );

    expect(result.outcome, PendingRecordingUploadOutcome.uploaded);
    expect(result.error, isNull);
    expect(uploader.attemptCount, 1);
    expect(uploader.recordingIds, [draft.recordingId]);
    expect(uploader.audioBytes.single, [1, 2, 3]);
    expect(store.removedDrafts, [draft]);
  });

  test('retries a recoverable upload once with the same draft', () async {
    final store = _MemoryPendingRecordingDraftStore(draft: draft);
    final uploader = _FakePendingRecordingUploader(
      errors: [
        const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.requestTimeout,
        ),
      ],
    );
    final coordinator = PendingRecordingUploadCoordinator(
      store: store,
      uploader: uploader.call,
    );

    final result = await coordinator.upload(
      couple: activeCouple(),
      draft: draft,
    );

    expect(result.outcome, PendingRecordingUploadOutcome.uploaded);
    expect(uploader.attemptCount, 2);
    expect(uploader.recordingIds, [draft.recordingId, draft.recordingId]);
    expect(store.removedDrafts, [draft]);
  });

  test('retains a draft after recoverable retries are exhausted', () async {
    const timeout = CoupleRecordingRepositoryException(
      CoupleRecordingFailureReason.requestTimeout,
    );
    final store = _MemoryPendingRecordingDraftStore(draft: draft);
    final uploader = _FakePendingRecordingUploader(
      errors: const [timeout, timeout],
    );
    final coordinator = PendingRecordingUploadCoordinator(
      store: store,
      uploader: uploader.call,
    );

    final result = await coordinator.upload(
      couple: activeCouple(),
      draft: draft,
    );

    expect(result.outcome, PendingRecordingUploadOutcome.retained);
    expect(result.error, timeout);
    expect(uploader.attemptCount, 2);
    expect(store.removedDrafts, isEmpty);
  });

  test('discards a draft rejected by the write contract', () async {
    const terminalError = CoupleRecordingRepositoryException(
      CoupleRecordingFailureReason.invalidRecordingPath,
    );
    final store = _MemoryPendingRecordingDraftStore(draft: draft);
    final uploader = _FakePendingRecordingUploader(
      errors: const [terminalError],
    );
    final coordinator = PendingRecordingUploadCoordinator(
      store: store,
      uploader: uploader.call,
    );

    final result = await coordinator.upload(
      couple: activeCouple(),
      draft: draft,
    );

    expect(result.outcome, PendingRecordingUploadOutcome.discarded);
    expect(result.error, terminalError);
    expect(uploader.attemptCount, 1);
    expect(store.removedDrafts, [draft]);
  });

  test('coalesces concurrent requests into one upload', () async {
    final store = _MemoryPendingRecordingDraftStore(draft: draft);
    final uploadBarrier = Completer<void>();
    final uploader = _FakePendingRecordingUploader(barrier: uploadBarrier);
    final coordinator = PendingRecordingUploadCoordinator(
      store: store,
      uploader: uploader.call,
    );

    final first = coordinator.upload(couple: activeCouple(), draft: draft);
    final second = coordinator.upload(couple: activeCouple(), draft: draft);
    await Future<void>.delayed(Duration.zero);

    expect(uploader.attemptCount, 1);
    uploadBarrier.complete();

    expect((await first).outcome, PendingRecordingUploadOutcome.uploaded);
    expect((await second).outcome, PendingRecordingUploadOutcome.uploaded);
    expect(store.removedDrafts, [draft]);
  });

  test('delegates persisted draft lifecycle to its store', () async {
    final store = _MemoryPendingRecordingDraftStore(draft: draft);
    final coordinator = PendingRecordingUploadCoordinator(
      store: store,
      uploader: _FakePendingRecordingUploader().call,
    );

    expect(await coordinator.load(), draft);
    expect(
      await coordinator.createFilePath(draft.recordingId),
      'memory://${draft.recordingId}.m4a',
    );

    await coordinator.persist(draft);
    await coordinator.discard(draft);

    expect(store.persistedDrafts, [draft]);
    expect(store.removedDrafts, [draft]);
  });
}

class _MemoryPendingRecordingDraftStore
    implements PendingRecordingDraftStore {
  _MemoryPendingRecordingDraftStore({required this.draft});

  PendingRecordingDraft? draft;
  final persistedDrafts = <PendingRecordingDraft>[];
  final removedDrafts = <PendingRecordingDraft>[];

  @override
  Future<String> createFilePath(String recordingId) async {
    return 'memory://$recordingId.m4a';
  }

  @override
  Future<PendingRecordingDraft?> load() async => draft;

  @override
  Future<void> persist(PendingRecordingDraft draft) async {
    this.draft = draft;
    persistedDrafts.add(draft);
  }

  @override
  Future<Uint8List> readAudioBytes(PendingRecordingDraft draft) async {
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> remove(PendingRecordingDraft draft) async {
    this.draft = null;
    removedDrafts.add(draft);
  }
}

class _FakePendingRecordingUploader {
  _FakePendingRecordingUploader({
    List<Object> errors = const [],
    this.barrier,
  }) : _errors = List<Object>.from(errors);

  final List<Object> _errors;
  final Completer<void>? barrier;
  final recordingIds = <String>[];
  final audioBytes = <Uint8List>[];
  int attemptCount = 0;

  Future<void> call({
    required Couple couple,
    required PendingRecordingDraft draft,
    required Uint8List audioBytes,
  }) async {
    attemptCount += 1;
    recordingIds.add(draft.recordingId);
    this.audioBytes.add(audioBytes);
    await barrier?.future;
    if (_errors.isNotEmpty) {
      throw _errors.removeAt(0);
    }
  }
}
