import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../couple/data/couple.dart';
import '../data/couple_recording_failure.dart';
import '../data/recording_id_generator.dart';
import 'couple_recording_overview_controller.dart';
import 'recording_capture_error_messages.dart';
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
  static const _recordConfig = RecordConfig(encoder: AudioEncoder.aacLc);

  late final AudioRecorder _recorder;
  Timer? _ticker;
  DateTime? _startedAt;
  String? _filePath;
  Couple? _couple;
  bool _pendingStopAfterPrepare = false;

  @override
  RecordingCaptureState build() {
    _recorder = AudioRecorder();
    ref.onDispose(() {
      _ticker?.cancel();
      unawaited(_disposeRecorderAndDraft(_filePath));
    });
    return const RecordingCaptureState.idle();
  }

  Future<void> startRecording(Couple couple) async {
    if (!couple.canEditSharedData || !state.isIdle) {
      return;
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
        _clearDraftState();
        state = const RecordingCaptureState.idle().copyWith(
          errorMessage: '마이크 권한이 필요해요.',
        );
        return;
      }

      final tempDirectory = await getTemporaryDirectory();
      final filePath =
          '${tempDirectory.path}${Platform.pathSeparator}'
          '${generateRecordingId().replaceAll('-', '')}.m4a';

      _filePath = filePath;
      await _recorder.start(_recordConfig, path: filePath);

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

    _clearDraftState();
    state = const RecordingCaptureState.idle();
    await deleteRecordingDraftFile(filePath);
  }

  Future<void> _stopAndUploadRecording() async {
    final activeCouple = _couple;
    if (activeCouple == null) {
      await _cancelRecording();
      return;
    }

    _ticker?.cancel();
    state = state.copyWith(phase: RecordingCapturePhase.uploading);
    var cleanupPath = _filePath;

    try {
      final stoppedPath = await _recorder.stop();
      final filePath = stoppedPath ?? _filePath;
      if (filePath == null) {
        throw const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.storage,
        );
      }
      cleanupPath = filePath;

      final audioBytes = await File(filePath).readAsBytes();
      final durationMs = state.elapsedMs
          .clamp(1, recordingMaxDurationMs)
          .toInt();

      await ref
          .read(coupleRecordingOverviewControllerProvider.notifier)
          .uploadCurrentRecording(
            couple: activeCouple,
            audioBytes: audioBytes,
            durationMs: durationMs,
          );

      _clearDraftState();
      state = const RecordingCaptureState.idle();
    } catch (error) {
      try {
        await _recorder.cancel();
      } catch (_) {}
      _clearDraftState();
      state = const RecordingCaptureState.idle().copyWith(
        errorMessage: recordingCaptureErrorMessage(error),
      );
    } finally {
      await deleteRecordingDraftFile(cleanupPath);
    }
  }

  Future<void> _disposeRecorderAndDraft(String? filePath) async {
    try {
      await _recorder.dispose();
    } catch (_) {}
    await deleteRecordingDraftFile(filePath);
  }

  void _clearDraftState() {
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    _filePath = null;
    _couple = null;
    _pendingStopAfterPrepare = false;
  }
}
