import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../couple/data/couple.dart';
import 'recording_capture_error_messages.dart';
import '../data/couple_recording_failure.dart';
import '../data/recording_id_generator.dart';
import 'couple_recording_overview_controller.dart';

final recordingCaptureControllerProvider = NotifierProvider<
  RecordingCaptureController,
  RecordingCaptureState
>(RecordingCaptureController.new);

enum RecordingCapturePhase { idle, preparing, recording, uploading }

class RecordingCaptureState {
  const RecordingCaptureState({
    required this.phase,
    required this.elapsedMs,
    required this.isCancelArmed,
    this.errorMessage,
  });

  const RecordingCaptureState.idle()
    : this(
        phase: RecordingCapturePhase.idle,
        elapsedMs: 0,
        isCancelArmed: false,
      );

  final RecordingCapturePhase phase;
  final int elapsedMs;
  final bool isCancelArmed;
  final String? errorMessage;

  bool get isIdle => phase == RecordingCapturePhase.idle;

  bool get isPreparing => phase == RecordingCapturePhase.preparing;

  bool get isRecording => phase == RecordingCapturePhase.recording;

  bool get isUploading => phase == RecordingCapturePhase.uploading;

  RecordingCaptureState copyWith({
    RecordingCapturePhase? phase,
    int? elapsedMs,
    bool? isCancelArmed,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecordingCaptureState(
      phase: phase ?? this.phase,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      isCancelArmed: isCancelArmed ?? this.isCancelArmed,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class RecordingCaptureController extends Notifier<RecordingCaptureState> {
  static const _maxDurationMs = 15000;
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
      unawaited(_recorder.dispose());
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
      isCancelArmed: false,
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

      await _recorder.start(_recordConfig, path: filePath);

      if (_pendingStopAfterPrepare) {
        _pendingStopAfterPrepare = false;
        await _recorder.cancel();
        _clearDraftState();
        state = const RecordingCaptureState.idle();
        return;
      }

      _filePath = filePath;
      _startedAt = DateTime.now();
      _ticker?.cancel();
      _ticker = Timer.periodic(_tickInterval, (_) {
        final startedAt = _startedAt;
        if (startedAt == null || !state.isRecording) {
          return;
        }

        final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
        if (elapsedMs >= _maxDurationMs) {
          state = state.copyWith(elapsedMs: _maxDurationMs);
          unawaited(finishGesture());
          return;
        }

        state = state.copyWith(elapsedMs: elapsedMs);
      });

      state = const RecordingCaptureState(
        phase: RecordingCapturePhase.recording,
        elapsedMs: 0,
        isCancelArmed: false,
      );
    } catch (error) {
      _clearDraftState();
      state = const RecordingCaptureState.idle().copyWith(
        errorMessage: recordingCaptureErrorMessage(error),
      );
    }
  }

  void updateDragOffset(double deltaY) {
    if (!state.isRecording) {
      return;
    }

    final shouldCancel = deltaY <= -48;
    if (shouldCancel == state.isCancelArmed) {
      return;
    }

    state = state.copyWith(isCancelArmed: shouldCancel);
  }

  Future<void> finishGesture() async {
    if (state.isPreparing) {
      _pendingStopAfterPrepare = true;
      return;
    }

    if (!state.isRecording) {
      return;
    }

    if (state.isCancelArmed) {
      await _cancelRecording();
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

    try {
      await _recorder.cancel();
    } catch (_) {}

    _clearDraftState();
    state = const RecordingCaptureState.idle();
  }

  Future<void> _stopAndUploadRecording() async {
    final activeCouple = _couple;
    if (activeCouple == null) {
      _clearDraftState();
      state = const RecordingCaptureState.idle();
      return;
    }

    _ticker?.cancel();
    state = state.copyWith(
      phase: RecordingCapturePhase.uploading,
      isCancelArmed: false,
    );

    try {
      final stoppedPath = await _recorder.stop();
      final filePath = stoppedPath ?? _filePath;
      if (filePath == null) {
        throw const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.storage,
        );
      }

      final audioBytes = await File(filePath).readAsBytes();
      final durationMs = state.elapsedMs.clamp(1, _maxDurationMs).toInt();

      await ref
          .read(coupleRecordingOverviewControllerProvider.notifier)
          .uploadCurrentRecording(
            couple: activeCouple,
            audioBytes: Uint8List.fromList(audioBytes),
            durationMs: durationMs,
          );

      _clearDraftState();
      state = const RecordingCaptureState.idle();
    } catch (error) {
      _clearDraftState();
      state = const RecordingCaptureState.idle().copyWith(
        errorMessage: recordingCaptureErrorMessage(error),
      );
    }
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
