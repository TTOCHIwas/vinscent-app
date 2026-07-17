import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/story_card_scene.dart';
import 'story_card_preview_surface.dart';

const _closeTooltip = '\uce74\ub4dc \uc0c1\uc138 \ub2eb\uae30';
const _cardSemanticsLabel = '\uc2a4\ud1a0\ub9ac \uce74\ub4dc \uc0c1\uc138';

Future<void> showStoryCardDetailOverlay({
  required BuildContext context,
  required String cardId,
  required String? previewUrl,
}) {
  final barrierLabel = MaterialLocalizations.of(
    context,
  ).modalBarrierDismissLabel;

  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: const Color(0xB3000000),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _StoryCardDetailOverlay(cardId: cardId, previewUrl: previewUrl);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

class _StoryCardDetailOverlay extends StatelessWidget {
  const _StoryCardDetailOverlay({
    required this.cardId,
    required this.previewUrl,
  });

  static const _horizontalMargin = 16.0;
  static const _verticalMargin = 24.0;
  static const _closeButtonExtent = 44.0;

  final String cardId;
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('story-card-detail-overlay'),
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(
          horizontal: _horizontalMargin,
          vertical: _verticalMargin,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widthBound = math.max(0.0, constraints.maxWidth);
            final heightBound = math.max(
              0.0,
              constraints.maxHeight - _closeButtonExtent,
            );
            final cardWidth = math.min(
              widthBound,
              heightBound * storyCardCanvasAspectRatio,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: StoryCardPreviewSurface(
                      surfaceKey: Key('story-card-detail-$cardId'),
                      previewUrl: previewUrl,
                      width: cardWidth,
                      semanticsLabel: _cardSemanticsLabel,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    key: const Key('story-card-detail-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: _closeTooltip,
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(_closeButtonExtent),
                      backgroundColor: const Color(0x99000000),
                      foregroundColor: AppColors.textInverse,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 26),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
