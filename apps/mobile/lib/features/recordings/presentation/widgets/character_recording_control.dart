import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/app_attention_indicator.dart';
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
    this.onPrimaryTap,
    this.primaryTapSemanticsLabel,
    this.onPlaybackPressed,
    this.onRecordStart,
    this.onRecordEnd,
    this.showAttentionIndicator = false,
  });

  static const controlKey = ValueKey<String>('character-recording-control');
  static const progressKey = ValueKey<String>(
    'character-recording-control-progress',
  );
  static const playbackProgressKey = progressKey;
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
  final VoidCallback? onPrimaryTap;
  final String? primaryTapSemanticsLabel;
  final VoidCallback? onPlaybackPressed;
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordEnd;
  final bool showAttentionIndicator;

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

  bool get _canStopRecording =>
      (_isPreparing || _isRecording) && widget.onRecordEnd != null;

  VoidCallback? get _primaryTapAction => _canStopRecording
      ? widget.onRecordEnd
      : widget.onPrimaryTap ?? widget.onPlaybackPressed;

  bool get _canTap {
    if (_canStopRecording) {
      return !widget.isLoading && _primaryTapAction != null;
    }

    return (widget.onPrimaryTap != null ||
            (widget.recordingKey != null &&
                widget.onPlaybackPressed != null)) &&
        !_isCaptureBusy &&
        !widget.isLoading &&
        !widget.isPlaybackBusy &&
        _primaryTapAction != null;
  }

  bool get _canStartRecording =>
      widget.canRecord &&
      widget.capturePhase == RecordingCapturePhase.idle &&
      !widget.isLoading &&
      !widget.isPlaybackBusy &&
      widget.onRecordStart != null;

  bool get _canFinishRecording =>
      (_canStartRecording || _isPreparing || _isRecording) &&
      widget.onRecordEnd != null;

  bool get _showCaptureProgress =>
      widget.isLoading || _isPreparing || _isRecording || _isUploading;

  bool get _canPress => _canTap || _canStartRecording;

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
    final progressWidth = math.min(48.0, widget.size);
    final showPlaybackProgress =
        _showPlaybackProgress &&
        widget.isPlaybackBusy &&
        !widget.isPlaying &&
        !_isCaptureBusy &&
        !widget.isLoading;
    final showProgress = _showCaptureProgress || showPlaybackProgress;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        enabled: _canPress,
        excludeSemantics: true,
        label: _semanticsLabel(),
        onTap: _canTap ? _primaryTapAction : null,
        child: GestureDetector(
          key: CharacterRecordingControl.controlKey,
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _canPress ? (_) => _setPressed(true) : null,
          onTapUp: _canPress ? (_) => _setPressed(false) : null,
          onTapCancel: _canPress ? () => _setPressed(false) : null,
          onTap: _canTap ? _primaryTapAction : null,
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
                  _isCaptureBusy ||
                  widget.isLoading ||
                  (widget.isPlaybackBusy && !widget.isPlaying),
              transitionKey: CharacterRecordingControl.pulseKey,
              child: AnimatedScale(
                scale: _isPressed ? 0.96 : 1,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AppAttentionIndicator(
                      key: CharacterRecordingControl.recordingDotKey,
                      isVisible: widget.showAttentionIndicator,
                      semanticsLabel: '새 녹음 있음',
                      alignment: const Alignment(0.62, -0.62),
                      offset: Offset.zero,
                      child: widget.child,
                    ),
                    if (showProgress)
                      Positioned(
                        left: (widget.size - progressWidth) / 2,
                        bottom: 4,
                        width: progressWidth,
                        child: IgnorePointer(
                          child: _CharacterActivityProgress(
                            value: progressValue,
                            color: progressColor,
                          ),
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
      return '녹음 종료';
    }
    if (widget.onPrimaryTap != null) {
      return widget.primaryTapSemanticsLabel ?? '캐릭터 열기';
    }
    if (widget.isPlaying) {
      return '재생 일시정지';
    }
    if (widget.recordingKey != null) {
      return widget.showAttentionIndicator
          ? '새 녹음 재생, 길게 눌러 다시 녹음'
          : '녹음 재생, 길게 눌러 다시 녹음';
    }
    return '길게 눌러 녹음';
  }
}

class _CharacterActivityProgress extends StatelessWidget {
  const _CharacterActivityProgress({required this.value, required this.color});

  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        key: CharacterRecordingControl.progressKey,
        value: value,
        minHeight: 3,
        color: color,
        backgroundColor: AppColors.actionDisabled,
      ),
    );
  }
}
