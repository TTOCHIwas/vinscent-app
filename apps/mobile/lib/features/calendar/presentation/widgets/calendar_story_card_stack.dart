import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../story_loops/data/story_loop_card_detail.dart';
import '../../../story_loops/data/story_card_scene.dart';

class CalendarStoryCardStack extends StatelessWidget {
  const CalendarStoryCardStack({super.key, required this.cards});

  final List<StoryLoopCardDetail> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedCards = [...cards]
      ..sort((left, right) => left.submittedAt.compareTo(right.submittedAt));
    final visibleCards = sortedCards.take(2).toList(growable: false);
    if (visibleCards.length == 1) {
      return Center(
        child: _StoryCardSurface(card: visibleCards.first, width: 180),
      );
    }

    return Center(
      child: SizedBox(
        width: 280,
        height: 330,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 8,
              top: 10,
              child: Transform.rotate(
                angle: -0.05,
                child: _StoryCardSurface(
                  card: visibleCards.first,
                  width: 170,
                  backgroundColor: const Color(0xFFF3F0EA),
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 18,
              child: Transform.rotate(
                angle: 0.1,
                child: _StoryCardSurface(
                  card: visibleCards[1],
                  width: 170,
                  backgroundColor: const Color(0xFFEAF2EF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCardSurface extends StatelessWidget {
  const _StoryCardSurface({
    required this.card,
    required this.width,
    this.backgroundColor = Colors.white,
  });

  final StoryLoopCardDetail card;
  final double width;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final previewUrl = card.previewUrl;
    final previewUri = previewUrl == null ? null : Uri.tryParse(previewUrl);
    final hasRemotePreview =
        previewUri != null &&
        previewUri.hasScheme &&
        (previewUri.scheme == 'http' || previewUri.scheme == 'https');

    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: storyCardCanvasAspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.wireframeBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Positioned.fill(
                  child: hasRemotePreview
                      ? Image.network(
                          previewUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return _StoryCardPlaceholder(card: card);
                          },
                        )
                      : _StoryCardPlaceholder(card: card),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _StoryCardContentKinds(card: card),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC171717),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        _formatTime(card.submittedAt),
                        style: AppTextStyles.homeCharacterLabel.copyWith(
                          color: AppColors.textInverse,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryCardPlaceholder extends StatelessWidget {
  const _StoryCardPlaceholder({required this.card});

  final StoryLoopCardDetail card;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (_contentCount(card)) {
      3 => const Color(0xFF6B8E8E),
      2 => const Color(0xFF8E786B),
      _ => const Color(0xFF7C7C7C),
    };

    return ColoredBox(
      color: const Color(0xFFF8F8F8),
      child: Center(
        child: Icon(
          Icons.auto_awesome_mosaic_outlined,
          size: 40,
          color: accentColor,
        ),
      ),
    );
  }

  int _contentCount(StoryLoopCardDetail card) {
    var count = 0;
    if (card.hasPhoto) {
      count += 1;
    }
    if (card.hasDrawing) {
      count += 1;
    }
    if (card.hasText) {
      count += 1;
    }
    return math.max(count, 1);
  }
}

class _StoryCardContentKinds extends StatelessWidget {
  const _StoryCardContentKinds({required this.card});

  final StoryLoopCardDetail card;

  @override
  Widget build(BuildContext context) {
    final icons = <IconData>[
      if (card.hasPhoto) Icons.image_outlined,
      if (card.hasDrawing) Icons.brush_outlined,
      if (card.hasText) Icons.text_fields,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < icons.length; index++) ...[
              Icon(icons[index], size: 14, color: AppColors.textPrimary),
              if (index < icons.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
