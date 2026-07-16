import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/recording_capture_controller.dart';

class RecordingControlButton extends StatelessWidget {
  const RecordingControlButton({
    super.key,
    required this.capturePhase,
    required this.recordingProgress,
    required this.hasRecording,
    required this.isPlaying,
    required this.isPlaybackBusy,
    required this.isLoading,
    required this.canRecord,
    this.onPlaybackPressed,
    this.onRecordStart,
    this.onRecordEnd,
  });

  static const buttonKey = ValueKey<String>('recording-control-button');
  static const surfaceKey = ValueKey<String>(
    'recording-control-button-surface',
  );
  static const progressKey = ValueKey<String>(
    'recording-control-button-progress',
  );

  static const _controlSize = 104.0;
  static const _buttonSize = 84.0;

  final RecordingCapturePhase capturePhase;
  final double recordingProgress;
  final bool hasRecording;
  final bool isPlaying;
  final bool isPlaybackBusy;
  final bool isLoading;
  final bool canRecord;
  final VoidCallback? onPlaybackPressed;
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordEnd;

  @override
  Widget build(BuildContext context) {
    final isPreparing = capturePhase == RecordingCapturePhase.preparing;
    final isRecording = capturePhase == RecordingCapturePhase.recording;
    final isUploading = capturePhase == RecordingCapturePhase.uploading;
    final isCaptureBusy = isPreparing || isRecording || isUploading;
    final canPlay =
        hasRecording &&
        !isCaptureBusy &&
        !isLoading &&
        !isPlaybackBusy &&
        onPlaybackPressed != null;
    final canStartRecording =
        canRecord &&
        capturePhase == RecordingCapturePhase.idle &&
        !isLoading &&
        !isPlaybackBusy &&
        onRecordStart != null;
    final canFinishRecording =
        (canStartRecording || isPreparing || isRecording) &&
        onRecordEnd != null;
    final isUnavailable = !hasRecording && !canRecord;
    final showProgress =
        isLoading ||
        isPlaybackBusy ||
        isPreparing ||
        isRecording ||
        isUploading;

    final backgroundColor = isPreparing || isRecording
        ? AppColors.recordingActive
        : isUnavailable || isLoading || isUploading
        ? AppColors.actionDisabled
        : AppColors.actionPrimary;
    final contentColor = isUnavailable || isLoading || isUploading
        ? AppColors.actionDisabledContent
        : AppColors.textInverse;
    final progressColor = isPreparing || isRecording
        ? AppColors.recordingActive
        : AppColors.actionPrimary;
    final progressValue = isRecording
        ? recordingProgress.clamp(0.0, 1.0)
        : null;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        enabled: canPlay || canStartRecording,
        label: _semanticsLabel(
          isPreparing: isPreparing,
          isRecording: isRecording,
          isUploading: isUploading,
        ),
        onTap: canPlay ? onPlaybackPressed : null,
        child: GestureDetector(
          key: buttonKey,
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: canPlay ? onPlaybackPressed : null,
          onLongPressStart: canStartRecording
              ? (_) => onRecordStart?.call()
              : null,
          onLongPressEnd: canFinishRecording
              ? (_) => onRecordEnd?.call()
              : null,
          child: SizedBox.square(
            dimension: _controlSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showProgress)
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      key: progressKey,
                      value: progressValue,
                      strokeWidth: 5,
                      color: progressColor,
                      backgroundColor: AppColors.actionDisabled,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                AnimatedContainer(
                  key: surfaceKey,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  width: _buttonSize,
                  height: _buttonSize,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUnavailable
                          ? AppColors.wireframeBorder
                          : backgroundColor,
                    ),
                  ),
                  child: Icon(
                    _iconForState(isRecording: isRecording),
                    size: 34,
                    color: contentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForState({required bool isRecording}) {
    if (isRecording || capturePhase == RecordingCapturePhase.preparing) {
      return Icons.mic_rounded;
    }
    if (isPlaying) {
      return Icons.pause_rounded;
    }
    if (hasRecording) {
      return Icons.play_arrow_rounded;
    }
    return Icons.mic_rounded;
  }

  String _semanticsLabel({
    required bool isPreparing,
    required bool isRecording,
    required bool isUploading,
  }) {
    if (isUploading) {
      return '녹음 저장 중';
    }
    if (isPreparing || isRecording) {
      return '녹음 중';
    }
    if (isPlaying) {
      return '재생 일시정지';
    }
    if (hasRecording) {
      return '녹음 재생';
    }
    return '길게 눌러 녹음';
  }
}
