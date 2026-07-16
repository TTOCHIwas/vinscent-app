import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/recording_capture_controller.dart';

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
    this.onPlaybackPressed,
    this.onRecordStart,
    this.onRecordEnd,
  });

  static const controlKey = ValueKey<String>('character-recording-control');
  static const progressKey = ValueKey<String>(
    'character-recording-control-progress',
  );
  static const pulseKey = ValueKey<String>('character-recording-control-pulse');

  final RecordingCapturePhase capturePhase;
  final double recordingProgress;
  final String? recordingKey;
  final bool isPlaying;
  final bool isPlaybackBusy;
  final bool isLoading;
  final bool canRecord;
  final Widget child;
  final VoidCallback? onPlaybackPressed;
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordEnd;

  @override
  State<CharacterRecordingControl> createState() =>
      _CharacterRecordingControlState();
}

class _CharacterRecordingControlState extends State<CharacterRecordingControl>
    with SingleTickerProviderStateMixin {
  static const _controlSize = 184.0;
  static const _pulseDuration = Duration(milliseconds: 320);
  static const _noticePulsePeriods = 6;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  bool _isPressed = false;
  bool _isLongPressActive = false;

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

  bool get _showProgress =>
      widget.isLoading ||
      widget.isPlaybackBusy ||
      _isPreparing ||
      _isRecording ||
      _isUploading;

  bool get _canPress => _canPlay || _canStartRecording;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: _pulseDuration,
    );
    _pulseScale = Tween<double>(begin: 1, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _syncPulse(initial: true);
  }

  @override
  void didUpdateWidget(covariant CharacterRecordingControl oldWidget) {
    super.didUpdateWidget(oldWidget);

    final recordingChanged = oldWidget.recordingKey != widget.recordingKey;
    final playbackChanged = oldWidget.isPlaying != widget.isPlaying;
    final busyChanged =
        oldWidget.capturePhase != widget.capturePhase ||
        oldWidget.isLoading != widget.isLoading ||
        oldWidget.isPlaybackBusy != widget.isPlaybackBusy;

    if (recordingChanged || playbackChanged || busyChanged) {
      _syncPulse(
        notifyRecording: recordingChanged && widget.recordingKey != null,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _syncPulse({bool initial = false, bool notifyRecording = false}) {
    _pulseController.stop();
    _pulseController.value = 0;

    if (_isCaptureBusy || widget.isLoading || widget.isPlaybackBusy) {
      return;
    }
    if (widget.isPlaying) {
      _pulseController.repeat(reverse: true);
      return;
    }
    if ((initial || notifyRecording) && widget.recordingKey != null) {
      final ticker = _pulseController.repeat(
        reverse: true,
        count: _noticePulsePeriods,
      );
      ticker.whenCompleteOrCancel(() {
        if (!mounted || widget.isPlaying || _isCaptureBusy) {
          return;
        }
        _pulseController.value = 0;
      });
    }
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
            dimension: _controlSize,
            child: ScaleTransition(
              key: CharacterRecordingControl.pulseKey,
              scale: _pulseScale,
              child: AnimatedScale(
                scale: _isPressed ? 0.96 : 1,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.isPlaying && !_showProgress)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.actionPrimary,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    if (_showProgress)
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          key: CharacterRecordingControl.progressKey,
                          value: progressValue,
                          strokeWidth: 5,
                          color: progressColor,
                          backgroundColor: AppColors.actionDisabled,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    widget.child,
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
