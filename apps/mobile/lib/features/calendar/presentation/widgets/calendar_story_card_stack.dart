import 'dart:math' as math;

import 'package:flutter/material.dart';

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
                child: _StoryCardSurface(card: visibleCards.first, width: 170),
              ),
            ),
            Positioned(
              right: 6,
              top: 18,
              child: Transform.rotate(
                angle: 0.1,
                child: _StoryCardSurface(card: visibleCards[1], width: 170),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCardSurface extends StatelessWidget {
  const _StoryCardSurface({required this.card, required this.width});

  final StoryLoopCardDetail card;
  final double width;

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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
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
