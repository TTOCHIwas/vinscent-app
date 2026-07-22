import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/recordings/application/pending_recording_draft_store.dart';
import 'package:vinscent/features/recordings/application/pending_recording_upload_coordinator.dart';
import 'package:vinscent/features/recordings/application/recording_capture_controller.dart';
import 'package:vinscent/features/recordings/application/recording_capture_device.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  test('records and uploads through injected capture boundaries', () async {
    final device = _FakeRecordingCaptureDevice();
    final store = _MemoryPendingRecordingDraftStore();
    final uploader = _FakePendingRecordingUploader();
    final harness = _CaptureHarness(
      device: device,
      store: store,
      uploader: uploader,
    );
    addTearDown(harness.dispose);

    await harness.controller.startRecording(activeCouple());

    expect(harness.state.phase, RecordingCapturePhase.recording);
    expect(device.startedPaths, hasLength(1));

    await harness.controller.finishGesture();

    expect(harness.state.phase, RecordingCapturePhase.idle);
    expect(store.persistedDrafts, hasLength(1));
    expect(uploader.drafts, store.persistedDrafts);
    expect(uploader.audioBytes.single, [1, 2, 3]);
    expect(store.removedDrafts, store.persistedDrafts);
    expect(device.stopCount, 1);
  });

  test('cancels when the gesture ends while permission is preparing', () async {
    final permissionBarrier = Completer<bool>();
    final device = _FakeRecordingCaptureDevice(
      permissionBarrier: permissionBarrier,
    );
    final store = _MemoryPendingRecordingDraftStore();
    final uploader = _FakePendingRecordingUploader();
    final harness = _CaptureHarness(
      device: device,
      store: store,
      uploader: uploader,
    );
    addTearDown(harness.dispose);

    final start = harness.controller.startRecording(activeCouple());
    await _waitUntil(
      () => harness.state.phase == RecordingCapturePhase.preparing,
    );

    await harness.controller.finishGesture();
    permissionBarrier.complete(true);
    await start;

    expect(harness.state.phase, RecordingCapturePhase.idle);
    expect(device.cancelCount, 1);
    expect(store.persistedDrafts, isEmpty);
    expect(uploader.drafts, isEmpty);
  });

  test('restores and uploads a persisted draft on controller build', () async {
    const draft = PendingRecordingDraft(
      recordingId: '30000000-0000-0000-0000-000000000001',
      coupleId: 'couple-id',
      durationMs: 900,
    );
    final device = _FakeRecordingCaptureDevice();
    final store = _MemoryPendingRecordingDraftStore(draft: draft);
    final uploader = _FakePendingRecordingUploader();
    final harness = _CaptureHarness(
      device: device,
      store: store,
      uploader: uploader,
    );
    addTearDown(harness.dispose);

    await _waitUntil(() => uploader.drafts.isNotEmpty);

    expect(uploader.drafts, [draft]);
    expect(store.removedDrafts, [draft]);
    expect(harness.state.phase, RecordingCapturePhase.idle);
    expect(device.startedPaths, isEmpty);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(timeoutAt)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

class _CaptureHarness {
  _CaptureHarness({
    required RecordingCaptureDevice device,
    required PendingRecordingDraftStore store,
    required _FakePendingRecordingUploader uploader,
  }) : container = ProviderContainer(
         overrides: [
           recordingCaptureDeviceFactoryProvider.overrideWithValue(
             () => device,
           ),
           pendingRecordingUploadCoordinatorProvider.overrideWithValue(
             PendingRecordingUploadCoordinator(
               store: store,
               uploader: uploader.call,
             ),
           ),
           coupleControllerProvider.overrideWithBuild(
             (ref, notifier) async => activeCouple(),
           ),
         ],
       ) {
    subscription = container.listen(
      recordingCaptureControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    controller = container.read(recordingCaptureControllerProvider.notifier);
  }

  final ProviderContainer container;
  late final ProviderSubscription<RecordingCaptureState> subscription;
  late final RecordingCaptureController controller;

  RecordingCaptureState get state {
    return container.read(recordingCaptureControllerProvider);
  }

  void dispose() {
    subscription.close();
    container.dispose();
  }
}

class _FakeRecordingCaptureDevice implements RecordingCaptureDevice {
  _FakeRecordingCaptureDevice({this.permissionBarrier});

  final Completer<bool>? permissionBarrier;
  final startedPaths = <String>[];
  int stopCount = 0;
  int cancelCount = 0;
  int disposeCount = 0;

  @override
  Future<bool> hasPermission() async {
    return permissionBarrier?.future ?? true;
  }

  @override
  Future<void> start({required String path}) async {
    startedPaths.add(path);
  }

  @override
  Future<String?> stop() async {
    stopCount += 1;
    return startedPaths.lastOrNull;
  }

  @override
  Future<void> cancel() async {
    cancelCount += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }
}

class _MemoryPendingRecordingDraftStore implements PendingRecordingDraftStore {
  _MemoryPendingRecordingDraftStore({this.draft});

  PendingRecordingDraft? draft;
  final persistedDrafts = <PendingRecordingDraft>[];
  final removedDrafts = <PendingRecordingDraft>[];

  @override
  Future<String> createFilePath(String recordingId) async {
    return 'pending/$recordingId.m4a';
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
  final drafts = <PendingRecordingDraft>[];
  final audioBytes = <Uint8List>[];

  Future<void> call({
    required Couple couple,
    required PendingRecordingDraft draft,
    required Uint8List audioBytes,
  }) async {
    drafts.add(draft);
    this.audioBytes.add(audioBytes);
  }
}
