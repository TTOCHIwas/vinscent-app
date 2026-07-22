import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../data/couple_recording_failure.dart';
import '../data/recording_id_generator.dart';
import 'pending_recording_draft_store.dart';
import 'pending_recording_upload_coordinator.dart';
import 'recording_capture_error_messages.dart';
import 'recording_capture_device.dart';
import 'recording_draft_file.dart';

final recordingCaptureControllerProvider =
    NotifierProvider<RecordingCaptureController, RecordingCaptureState>(
      RecordingCaptureController.new,
    );

const recordingMaxDurationMs = 15000;

enum RecordingCapturePhase { idle, preparing, recording, uploading }

class RecordingCaptureState {
  const RecordingCaptureState({
    required this.phase,
    required this.elapsedMs,
    this.errorMessage,
  });

  const RecordingCaptureState.idle()
    : this(phase: RecordingCapturePhase.idle, elapsedMs: 0);

  final RecordingCapturePhase phase;
  final int elapsedMs;
  final String? errorMessage;

  bool get isIdle => phase == RecordingCapturePhase.idle;

  bool get isPreparing => phase == RecordingCapturePhase.preparing;

  bool get isRecording => phase == RecordingCapturePhase.recording;

  bool get isUploading => phase == RecordingCapturePhase.uploading;

  RecordingCaptureState copyWith({
    RecordingCapturePhase? phase,
    int? elapsedMs,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecordingCaptureState(
      phase: phase ?? this.phase,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class RecordingCaptureController extends Notifier<RecordingCaptureState> {
  static const _tickInterval = Duration(milliseconds: 100);

  late final RecordingCaptureDevice _recorder;
  late final PendingRecordingUploadCoordinator _draftCoordinator;
  Timer? _ticker;
  DateTime? _startedAt;
  String? _filePath;
  String? _recordingId;
  Couple? _couple;
  PendingRecordingDraft? _pendingDraft;
  Future<void>? _restoreFuture;
  bool _pendingStopAfterPrepare = false;

  @override
  RecordingCaptureState build() {
    _recorder = ref.read(recordingCaptureDeviceFactoryProvider)();
    _draftCoordinator = ref.read(pendingRecordingUploadCoordinatorProvider);
    _restoreFuture = Future<void>.microtask(_restorePendingRecording);
    ref.onDispose(() {
      _ticker?.cancel();
      unawaited(_disposeRecorderAndActiveDraft(_filePath));
    });
    return const RecordingCaptureState.idle();
  }

  Future<void> startRecording(Couple couple) async {
    if (!couple.canEditSharedData || !state.isIdle) {
      return;
    }

    final restoreFuture = _restoreFuture;
    if (restoreFuture != null) {
      await restoreFuture;
    }
    if (!ref.mounted || !state.isIdle) {
      return;
    }

    final pendingDraft = _pendingDraft ?? await _draftCoordinator.load();
    if (pendingDraft != null) {
      _pendingDraft = pendingDraft;
      if (pendingDraft.coupleId == couple.id) {
        await _uploadPendingRecording(
          couple: couple,
          draft: pendingDraft,
          showError: true,
        );
        return;
      }

      await _draftCoordinator.discard(pendingDraft);
      _pendingDraft = null;
    }

    _pendingStopAfterPrepare = false;
    _couple = couple;
    state = const RecordingCaptureState(
      phase: RecordingCapturePhase.preparing,
      elapsedMs: 0,
    );

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _clearActiveCaptureState();
        state = const RecordingCaptureState.idle().copyWith(
          errorMessage: '마이크 권한이 필요해요.',
        );
        return;
      }

      final recordingId = generateRecordingId();
      final filePath = await _draftCoordinator.createFilePath(recordingId);

      _recordingId = recordingId;
      _filePath = filePath;
      await _recorder.start(path: filePath);

      if (_pendingStopAfterPrepare) {
        await _cancelRecording();
        return;
      }

      _startedAt = DateTime.now();
      _ticker?.cancel();
      _ticker = Timer.periodic(_tickInterval, (_) {
        final startedAt = _startedAt;
        if (startedAt == null || !state.isRecording) {
          return;
        }

        final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
        if (elapsedMs >= recordingMaxDurationMs) {
          state = state.copyWith(elapsedMs: recordingMaxDurationMs);
          unawaited(finishGesture());
          return;
        }

        state = state.copyWith(elapsedMs: elapsedMs);
      });

      state = const RecordingCaptureState(
        phase: RecordingCapturePhase.recording,
        elapsedMs: 0,
      );
    } catch (error) {
      await _cancelRecording();
      state = const RecordingCaptureState.idle().copyWith(
        errorMessage: recordingCaptureErrorMessage(error),
      );
    }
  }

  Future<void> finishGesture() async {
    if (state.isPreparing) {
      _pendingStopAfterPrepare = true;
      return;
    }

    if (!state.isRecording) {
      return;
    }

    await _stopAndUploadRecording();
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }

    state = state.copyWith(clearError: true);
  }

  Future<void> _cancelRecording() async {
    _ticker?.cancel();
    final filePath = _filePath;

    try {
      await _recorder.cancel();
    } catch (_) {}

    _clearActiveCaptureState();
    state = const RecordingCaptureState.idle();
    await deleteRecordingDraftFile(filePath);
  }

  Future<void> _stopAndUploadRecording() async {
    final activeCouple = _couple;
    final recordingId = _recordingId;
    if (activeCouple == null || recordingId == null) {
      await _cancelRecording();
      return;
    }

    _ticker?.cancel();
    state = state.copyWith(phase: RecordingCapturePhase.uploading);
    final activeFilePath = _filePath;

    try {
      final stoppedPath = await _recorder.stop();
      final filePath = activeFilePath ?? stoppedPath;
      if (filePath == null) {
        throw const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.storage,
        );
      }
      final durationMs = state.elapsedMs
          .clamp(1, recordingMaxDurationMs)
          .toInt();
      final draft = PendingRecordingDraft(
        recordingId: recordingId,
        coupleId: activeCouple.id,
        durationMs: durationMs,
      );

      if (stoppedPath != null && stoppedPath != filePath) {
        await File(stoppedPath).copy(filePath);
        await deleteRecordingDraftFile(stoppedPath);
      }

      await _draftCoordinator.persist(draft);
      _pendingDraft = draft;
      _clearActiveCaptureState();

      await _uploadPendingRecording(
        couple: activeCouple,
        draft: draft,
        showError: true,
      );
    } catch (error) {
      try {
        await _recorder.cancel();
      } catch (_) {}
      _clearActiveCaptureState();
      state = const RecordingCaptureState.idle().copyWith(
        errorMessage: recordingCaptureErrorMessage(error),
      );
      await deleteRecordingDraftFile(activeFilePath);
    }
  }

  Future<void> _restorePendingRecording() async {
    try {
      final draft = await _draftCoordinator.load();
      if (!ref.mounted || draft == null) {
        return;
      }
      _pendingDraft = draft;

      final couple = await ref.read(coupleControllerProvider.future);
      if (!ref.mounted || couple == null) {
        return;
      }
      if (couple.id != draft.coupleId || !couple.canEditSharedData) {
        await _draftCoordinator.discard(draft);
        _pendingDraft = null;
        return;
      }

      await _uploadPendingRecording(
        couple: couple,
        draft: draft,
        showError: false,
      );
    } catch (_) {}
  }

  Future<void> _uploadPendingRecording({
    required Couple couple,
    required PendingRecordingDraft draft,
    required bool showError,
  }) async {
    if (ref.mounted) {
      state = const RecordingCaptureState(
        phase: RecordingCapturePhase.uploading,
        elapsedMs: 0,
      );
    }

    final result = await _draftCoordinator.upload(couple: couple, draft: draft);
    _pendingDraft = result.outcome == PendingRecordingUploadOutcome.retained
        ? draft
        : null;
    if (!ref.mounted) {
      return;
    }

    final error = result.error;
    state = showError && error != null
        ? const RecordingCaptureState.idle().copyWith(
            errorMessage: recordingCaptureErrorMessage(error),
          )
        : const RecordingCaptureState.idle();
  }

  Future<void> _disposeRecorderAndActiveDraft(String? filePath) async {
    try {
      await _recorder.dispose();
    } catch (_) {}
    await deleteRecordingDraftFile(filePath);
  }

  void _clearActiveCaptureState() {
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    _filePath = null;
    _recordingId = null;
    _couple = null;
    _pendingStopAfterPrepare = false;
  }
}
