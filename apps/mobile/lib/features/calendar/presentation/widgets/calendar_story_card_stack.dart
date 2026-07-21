import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../story_loops/data/story_loop_card_detail.dart';
import '../../../story_loops/presentation/widgets/story_card_preview_surface.dart';

class CalendarStoryCardStack extends StatelessWidget {
  const CalendarStoryCardStack({
    super.key,
    required this.cards,
    this.currentUserId,
    this.onCardTap,
  });

  static const _maximumContentWidth = 360.0;
  static const _slotGap = 16.0;
  static const _maximumCardWidth = (_maximumContentWidth - _slotGap) / 2;

  final List<StoryLoopCardDetail> cards;
  final String? currentUserId;
  final ValueChanged<StoryLoopCardDetail>? onCardTap;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleCards = _orderedVisibleCards();
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth.clamp(0.0, _maximumContentWidth).toDouble()
            : _maximumContentWidth;

        if (visibleCards.length == 1) {
          final cardWidth = math.min(_maximumCardWidth, contentWidth);
          return Center(
            child: _CalendarStoryCard(
              card: visibleCards.first,
              width: cardWidth,
              onTap: _cardTapHandler(visibleCards.first),
            ),
          );
        }

        final gap = math.min(_slotGap, contentWidth);
        final cardWidth = math.min(
          _maximumCardWidth,
          math.max(0.0, (contentWidth - gap) / 2),
        );
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CalendarStoryCard(
                card: visibleCards.first,
                width: cardWidth,
                onTap: _cardTapHandler(visibleCards.first),
              ),
              SizedBox(width: gap),
              _CalendarStoryCard(
                card: visibleCards[1],
                width: cardWidth,
                onTap: _cardTapHandler(visibleCards[1]),
              ),
            ],
          ),
        );
      },
    );
  }

  VoidCallback? _cardTapHandler(StoryLoopCardDetail card) {
    final callback = onCardTap;
    return callback == null ? null : () => callback(card);
  }

  List<StoryLoopCardDetail> _orderedVisibleCards() {
    final sortedCards = [...cards]
      ..sort((left, right) => left.submittedAt.compareTo(right.submittedAt));
    final userId = currentUserId;
    if (userId == null) {
      return sortedCards.take(2).toList(growable: false);
    }

    final orderedCards = <StoryLoopCardDetail>[
      ...sortedCards.where((card) => card.authorUserId == userId).take(1),
      ...sortedCards.where((card) => card.authorUserId != userId).take(1),
    ];
    if (orderedCards.length < 2) {
      orderedCards.addAll(
        sortedCards.where((card) => !orderedCards.contains(card)),
      );
    }
    return orderedCards.take(2).toList(growable: false);
  }
}

class _CalendarStoryCard extends StatelessWidget {
  const _CalendarStoryCard({
    required this.card,
    required this.width,
    this.onTap,
  });

  final StoryLoopCardDetail card;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StoryCardPreviewSurface(
      surfaceKey: ValueKey('calendar-story-card-${card.id}'),
      previewUrl: card.previewUrl,
      width: width,
      onTap: onTap,
      semanticsLabel: '스토리 카드',
    );
  }
}
