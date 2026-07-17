import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/recording_capture_controller.dart';
import 'recording_pulse.dart';

class CharacterRecordingControl extends StatefulWidget {
  const CharacterRecordingControl({
    super.key,
    required this.capturePhase,
    required this.recordingProgress,
    required this.recordingKey,
    required this.isPlaying,
    required this.isPlaybackBusy,
    required this.isLoading,
    required this.canRecord,
    required this.child,
    this.size = 184,
    this.onPlaybackPressed,
    this.onRecordStart,
    this.onRecordEnd,
  });

  static const controlKey = ValueKey<String>('character-recording-control');
  static const progressKey = ValueKey<String>(
    'character-recording-control-progress',
  );
  static const playbackProgressKey = ValueKey<String>(
    'character-recording-control-playback-progress',
  );
  static const pulseKey = ValueKey<String>('character-recording-control-pulse');
  static const recordingDotKey = ValueKey<String>(
    'character-recording-control-recording-dot',
  );

  final RecordingCapturePhase capturePhase;
  final double recordingProgress;
  final String? recordingKey;
  final bool isPlaying;
  final bool isPlaybackBusy;
  final bool isLoading;
  final bool canRecord;
  final Widget child;
  final double size;
  final VoidCallback? onPlaybackPressed;
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordEnd;

  @override
  State<CharacterRecordingControl> createState() =>
      _CharacterRecordingControlState();
}

class _CharacterRecordingControlState extends State<CharacterRecordingControl> {
  static const _playbackProgressDelay = Duration(milliseconds: 150);

  bool _isPressed = false;
  bool _isLongPressActive = false;
  bool _showPlaybackProgress = false;
  Timer? _playbackProgressTimer;

  bool get _isPreparing =>
      widget.capturePhase == RecordingCapturePhase.preparing;

  bool get _isRecording =>
      widget.capturePhase == RecordingCapturePhase.recording;

  bool get _isUploading =>
      widget.capturePhase == RecordingCapturePhase.uploading;

  bool get _isCaptureBusy => _isPreparing || _isRecording || _isUploading;

  bool get _canPlay =>
      widget.recordingKey != null &&
      !_isCaptureBusy &&
      !widget.isLoading &&
      !widget.isPlaybackBusy &&
      widget.onPlaybackPressed != null;

  bool get _canStartRecording =>
      widget.canRecord &&
      widget.capturePhase == RecordingCapturePhase.idle &&
      !widget.isLoading &&
      !widget.isPlaybackBusy &&
      widget.onRecordStart != null;

  bool get _canFinishRecording =>
      (_canStartRecording || _isPreparing || _isRecording) &&
      widget.onRecordEnd != null;

  bool get _showTopProgress =>
      widget.isLoading || _isPreparing || _isRecording || _isUploading;

  bool get _canPress => _canPlay || _canStartRecording;

  @override
  void initState() {
    super.initState();
    _synchronizePlaybackProgress();
  }

  @override
  void didUpdateWidget(covariant CharacterRecordingControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaybackBusy != widget.isPlaybackBusy) {
      _synchronizePlaybackProgress();
    }
  }

  @override
  void dispose() {
    _playbackProgressTimer?.cancel();
    super.dispose();
  }

  void _synchronizePlaybackProgress() {
    _playbackProgressTimer?.cancel();
    _playbackProgressTimer = null;

    if (!widget.isPlaybackBusy) {
      _showPlaybackProgress = false;
      return;
    }

    _showPlaybackProgress = false;
    _playbackProgressTimer = Timer(_playbackProgressDelay, () {
      _playbackProgressTimer = null;
      if (!mounted || !widget.isPlaybackBusy) {
        return;
      }
      setState(() {
        _showPlaybackProgress = true;
      });
    });
  }

  void _setPressed(bool value) {
    if (_isPressed == value || !mounted) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _setPressed(false);
    _isLongPressActive = true;
    widget.onRecordStart?.call();
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    _finishLongPress();
  }

  void _handleLongPressCancel() {
    _finishLongPress();
  }

  void _finishLongPress() {
    _setPressed(false);
    if (!_isLongPressActive) {
      return;
    }
    _isLongPressActive = false;
    widget.onRecordEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final progressColor = _isPreparing || _isRecording
        ? AppColors.recordingActive
        : AppColors.actionPrimary;
    final progressValue = _isRecording
        ? widget.recordingProgress.clamp(0.0, 1.0)
        : null;
    final indicatorInset = math.min(16.0, widget.size / 4);
    final playbackProgressWidth = math.min(48.0, widget.size);
    final showPlaybackProgress =
        _showPlaybackProgress &&
        widget.isPlaybackBusy &&
        !widget.isPlaying &&
        !_isCaptureBusy &&
        !widget.isLoading;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        enabled: _canPress,
        excludeSemantics: true,
        label: _semanticsLabel(),
        onTap: _canPlay ? widget.onPlaybackPressed : null,
        child: GestureDetector(
          key: CharacterRecordingControl.controlKey,
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _canPress ? (_) => _setPressed(true) : null,
          onTapUp: _canPress ? (_) => _setPressed(false) : null,
          onTapCancel: _canPress ? () => _setPressed(false) : null,
          onTap: _canPlay ? widget.onPlaybackPressed : null,
          onLongPressStart: _canStartRecording ? _handleLongPressStart : null,
          onLongPressEnd: _canFinishRecording ? _handleLongPressEnd : null,
          onLongPressCancel: _canFinishRecording
              ? _handleLongPressCancel
              : null,
          child: SizedBox.square(
            dimension: widget.size,
            child: RecordingPulse(
              noticeKey: widget.recordingKey,
              isRepeating: widget.isPlaying,
              isDisabled:
                  _isCaptureBusy || widget.isLoading || widget.isPlaybackBusy,
              transitionKey: CharacterRecordingControl.pulseKey,
              child: AnimatedScale(
                scale: _isPressed ? 0.96 : 1,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_showTopProgress)
                      Positioned(
                        top: 0,
                        left: indicatorInset,
                        right: indicatorInset,
                        child: IgnorePointer(
                          child: _CharacterRecordingProgress(
                            value: progressValue,
                            color: progressColor,
                            showRecordingDot: _isPreparing || _isRecording,
                          ),
                        ),
                      ),
                    widget.child,
                    if (showPlaybackProgress)
                      Positioned(
                        left: (widget.size - playbackProgressWidth) / 2,
                        bottom: 4,
                        width: playbackProgressWidth,
                        child: const IgnorePointer(
                          child: _CharacterPlaybackProgress(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _semanticsLabel() {
    if (_isUploading) {
      return '녹음 저장 중';
    }
    if (_isPreparing || _isRecording) {
      return '녹음 중';
    }
    if (widget.isPlaying) {
      return '재생 일시정지';
    }
    if (widget.recordingKey != null) {
      return '녹음 재생, 길게 눌러 다시 녹음';
    }
    return '길게 눌러 녹음';
  }
}

class _CharacterPlaybackProgress extends StatelessWidget {
  const _CharacterPlaybackProgress();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: const LinearProgressIndicator(
        key: CharacterRecordingControl.playbackProgressKey,
        minHeight: 3,
        color: AppColors.actionPrimary,
        backgroundColor: AppColors.actionDisabled,
      ),
    );
  }
}

class _CharacterRecordingProgress extends StatelessWidget {
  const _CharacterRecordingProgress({
    required this.value,
    required this.color,
    required this.showRecordingDot,
  });

  final double? value;
  final Color color;
  final bool showRecordingDot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: Row(
        children: [
          if (showRecordingDot) ...[
            const SizedBox.square(
              key: CharacterRecordingControl.recordingDotKey,
              dimension: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.recordingActive,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                key: CharacterRecordingControl.progressKey,
                value: value,
                minHeight: 4,
                color: color,
                backgroundColor: AppColors.actionDisabled,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
