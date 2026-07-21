import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/recording_playback_controller.dart';
import '../../data/couple_recording.dart';
import 'recording_pulse.dart';

class HomeRecordingArtworkItem extends StatelessWidget {
  const HomeRecordingArtworkItem({
    required this.slot,
    required this.size,
    required this.isBusy,
    required this.isDragging,
    required this.pulseToken,
    required this.isPlaying,
    required this.onTap,
    this.onLongPress,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    super.key,
  });

  final CoupleRecordingSlot slot;
  final double size;
  final bool isBusy;
  final bool isDragging;
  final int? pulseToken;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;
  final VoidCallback? onPanCancel;

  @override
  Widget build(BuildContext context) {
    final artwork = slot.artwork;
    if (artwork == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${slot.title} 녹음 그림',
        child: GestureDetector(
          key: ValueKey('home-recording-artwork-${slot.slotId}'),
          behavior: HitTestBehavior.opaque,
          onTap: isBusy ? null : onTap,
          onLongPress: isBusy ? null : onLongPress,
          onPanStart: isBusy ? null : onPanStart,
          onPanUpdate: isBusy ? null : onPanUpdate,
          onPanEnd: isBusy ? null : onPanEnd,
          onPanCancel: isBusy ? null : onPanCancel,
          child: RecordingPulse(
            noticeKey: pulseToken,
            isRepeating: isPlaying,
            isDisabled: isBusy,
            transitionKey: ValueKey(
              'home-recording-artwork-pulse-${slot.slotId}',
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              scale: isDragging ? 1.06 : 1,
              child: Opacity(
                opacity: isBusy ? 0.55 : 1,
                child: Image.network(
                  artwork.previewUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
