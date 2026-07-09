import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../story_loops/data/story_loop_card_preview.dart';
import '../../../story_loops/data/story_loop_month_summary_day.dart';

class CalendarMonthStoryCell extends StatelessWidget {
  const CalendarMonthStoryCell({
    super.key,
    required this.date,
    required this.textColor,
    required this.summary,
  });

  final DateTime date;
  final Color textColor;
  final StoryLoopMonthSummaryDay? summary;

  @override
  Widget build(BuildContext context) {
    final visibleCards = _visibleCards(summary);
    final displayMode = switch (visibleCards.length) {
      0 => 'empty',
      1 => 'single',
      _ => 'stacked',
    };

    return Padding(
      key: ValueKey('calendar-month-story-cell-$displayMode-${_dateKey(date)}'),
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${date.day}',
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: textColor,
              fontSize: 11,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: _MonthStoryPreview(cards: visibleCards),
          ),
        ],
      ),
    );
  }

  List<StoryLoopCardPreview> _visibleCards(StoryLoopMonthSummaryDay? summary) {
    if (summary == null || summary.cardCount <= 0 || summary.cards.isEmpty) {
      return const [];
    }

    final sortedCards = [...summary.cards]
      ..sort((left, right) => left.submittedAt.compareTo(right.submittedAt));
    return sortedCards.take(2).toList(growable: false);
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _MonthStoryPreview extends StatelessWidget {
  const _MonthStoryPreview({required this.cards});

  final List<StoryLoopCardPreview> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.expand();
    }

    if (cards.length == 1) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: _MonthStorySurface(
          card: cards.first,
          width: 15,
          angle: 0,
          backgroundColor: const Color(0xFFF3F0EA),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 22,
        height: 18,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 1,
              bottom: 0,
              child: _MonthStorySurface(
                card: cards.first,
                width: 13,
                angle: -0.12,
                backgroundColor: const Color(0xFFF3F0EA),
              ),
            ),
            Positioned(
              right: 1,
              bottom: 0,
              child: _MonthStorySurface(
                card: cards[1],
                width: 13,
                angle: 0.14,
                backgroundColor: const Color(0xFFEAF2EF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthStorySurface extends StatelessWidget {
  const _MonthStorySurface({
    required this.card,
    required this.width,
    required this.angle,
    required this.backgroundColor,
  });

  final StoryLoopCardPreview card;
  final double width;
  final double angle;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final previewUri = Uri.tryParse(card.previewPath);
    final hasRemotePreview =
        previewUri != null &&
        previewUri.hasScheme &&
        (previewUri.scheme == 'http' || previewUri.scheme == 'https');

    return Transform.rotate(
      angle: angle,
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: 0.78,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.wireframeBorder, width: 0.7),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2.4),
              child: hasRemotePreview
                  ? Image.network(
                      card.previewPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _MonthStoryPlaceholder(card: card);
                      },
                    )
                  : _MonthStoryPlaceholder(card: card),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthStoryPlaceholder extends StatelessWidget {
  const _MonthStoryPlaceholder({required this.card});

  final StoryLoopCardPreview card;

  @override
  Widget build(BuildContext context) {
    final seed = card.authorUserId.codeUnits.fold<int>(
      0,
      (value, element) => value + element,
    );
    const palette = [
      Color(0xFFF2EDE7),
      Color(0xFFE9F0ED),
      Color(0xFFECEAF2),
      Color(0xFFF3EFE5),
    ];
    final color = palette[seed % palette.length];

    return ColoredBox(
      color: color,
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Color(0x66111111),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
