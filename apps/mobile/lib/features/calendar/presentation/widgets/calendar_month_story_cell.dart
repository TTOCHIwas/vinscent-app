import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../story_loops/data/story_loop_card_preview.dart';
import '../../../story_loops/data/story_card_scene.dart';
import '../../../story_loops/data/story_loop_month_summary_day.dart';
import '../../data/couple_calendar_event.dart';
import 'calendar_event_artwork.dart';

class CalendarMonthStoryCell extends StatelessWidget {
  const CalendarMonthStoryCell({
    super.key,
    required this.date,
    required this.textColor,
    required this.isSelected,
    required this.summary,
    this.events = const [],
    this.anniversaryLabel,
    this.eventIndicatorLimit = 1,
  });

  final DateTime date;
  final Color textColor;
  final bool isSelected;
  final StoryLoopMonthSummaryDay? summary;
  final List<CoupleCalendarEvent> events;
  final String? anniversaryLabel;
  final int eventIndicatorLimit;

  @override
  Widget build(BuildContext context) {
    final visibleCards = _visibleCards(summary);
    final displayMode = switch (visibleCards.length) {
      0 => 'empty',
      1 => 'single',
      _ => 'stacked',
    };

    return Padding(
      key: ValueKey(
        'calendar-month-story-cell-$displayMode-${_calendarDateKey(date)}',
      ),
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 18,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.actionPrimary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: AppTypography.applyToStyle(
                          AppTextStyles.homeCharacterLabel.copyWith(
                            color: isSelected
                                ? AppColors.textInverse
                                : textColor,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (anniversaryLabel case final label?) ...[
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: AppTypography.applyToStyle(
                        AppTextStyles.homeCharacterLabel.copyWith(
                          color: textColor,
                          fontSize: 10,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: _CalendarCellContent(
              date: date,
              events: events,
              eventIndicatorLimit: eventIndicatorLimit,
              cards: visibleCards,
            ),
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
}

class _CalendarCellContent extends StatelessWidget {
  const _CalendarCellContent({
    required this.date,
    required this.events,
    required this.eventIndicatorLimit,
    required this.cards,
  });

  static const _compactEventExtent = 16.0;
  static const _expandedEventExtent = 36.0;
  static const _minimumCardExtent = 12.0;

  final DateTime date;
  final List<CoupleCalendarEvent> events;
  final int eventIndicatorLimit;
  final List<StoryLoopCardPreview> cards;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _MonthStoryPreview(cards: cards);
    }

    if (cards.isEmpty) {
      return _CalendarEventIndicators(
        date: date,
        events: events,
        limit: eventIndicatorLimit,
        useAvailableSpace: true,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final preferredEventExtent = eventIndicatorLimit > 1
            ? _expandedEventExtent
            : _compactEventExtent;
        final availableEventExtent = math.max(
          0.0,
          constraints.maxHeight - _minimumCardExtent,
        );
        final eventExtent = math.min(
          preferredEventExtent,
          availableEventExtent,
        );

        return Column(
          children: [
            SizedBox(
              height: eventExtent,
              child: _CalendarEventIndicators(
                date: date,
                events: events,
                limit: eventIndicatorLimit,
                useAvailableSpace: false,
              ),
            ),
            const SizedBox(height: 1),
            Expanded(child: _MonthStoryPreview(cards: cards)),
          ],
        );
      },
    );
  }
}

class _CalendarEventIndicators extends StatelessWidget {
  const _CalendarEventIndicators({
    required this.date,
    required this.events,
    required this.limit,
    required this.useAvailableSpace,
  });

  static const _maximumArtworkSize = 48.0;
  static const _compactArtworkSize = 16.0;
  static const _artworkGap = 2.0;

  final DateTime date;
  final List<CoupleCalendarEvent> events;
  final int limit;
  final bool useAvailableSpace;

  @override
  Widget build(BuildContext context) {
    final sortedEvents = [...events]
      ..sort((left, right) {
        final artworkOrder = (right.artwork == null ? 0 : 1).compareTo(
          left.artwork == null ? 0 : 1,
        );
        if (artworkOrder != 0) {
          return artworkOrder;
        }
        return left.title.compareTo(right.title);
      });
    final visibleEvents = sortedEvents.take(limit).toList(growable: false);
    final overflowCount = events.length - visibleEvents.length;
    final isVertical = limit > 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final artworkSize = _resolveArtworkSize(
          constraints: constraints,
          artworkCount: visibleEvents.length,
          isVertical: isVertical,
        );
        final artworkWidgets = [
          for (var index = 0; index < visibleEvents.length; index++)
            _CalendarEventArtworkIndicator(
              date: date,
              event: visibleEvents[index],
              size: artworkSize,
              overflowCount: index == 0 ? overflowCount : 0,
            ),
        ];

        return Align(
          alignment: Alignment.center,
          child: isVertical
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _withSpacing(
                    artworkWidgets,
                    const SizedBox(height: _artworkGap),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _withSpacing(
                    artworkWidgets,
                    const SizedBox(width: _artworkGap),
                  ),
                ),
        );
      },
    );
  }

  double _resolveArtworkSize({
    required BoxConstraints constraints,
    required int artworkCount,
    required bool isVertical,
  }) {
    if (artworkCount == 0) {
      return 0;
    }

    final gapExtent = _artworkGap * math.max(0, artworkCount - 1);
    final widthLimit = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : _maximumArtworkSize;
    final heightLimit = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : _maximumArtworkSize;
    final mainAxisLimit = isVertical
        ? (heightLimit - gapExtent) / artworkCount
        : (widthLimit - gapExtent) / artworkCount;
    final crossAxisLimit = isVertical ? widthLimit : heightLimit;
    final maximumArtworkSize = useAvailableSpace
        ? _maximumArtworkSize
        : _compactArtworkSize;

    return math.max(
      0,
      math.min(maximumArtworkSize, math.min(mainAxisLimit, crossAxisLimit)),
    );
  }

  List<Widget> _withSpacing(List<Widget> widgets, Widget spacing) {
    return [
      for (var index = 0; index < widgets.length; index++) ...[
        if (index > 0) spacing,
        widgets[index],
      ],
    ];
  }
}

class _CalendarEventArtworkIndicator extends StatelessWidget {
  const _CalendarEventArtworkIndicator({
    required this.date,
    required this.event,
    required this.size,
    required this.overflowCount,
  });

  final DateTime date;
  final CoupleCalendarEvent event;
  final double size;
  final int overflowCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CalendarEventArtwork(
              key: ValueKey('calendar-event-indicator-${event.id}'),
              event: event,
              size: size,
            ),
          ),
          if (overflowCount > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text(
                    '+$overflowCount',
                    key: ValueKey(
                      'calendar-event-overflow-${_calendarDateKey(date)}',
                    ),
                    style: AppTypography.applyToStyle(
                      AppTextStyles.homeCharacterLabel.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _calendarDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class _MonthStoryPreview extends StatelessWidget {
  const _MonthStoryPreview({required this.cards});

  static const _maximumCardWidth = 48.0;
  static const _stackWidthFactor = 1.55;

  final List<StoryLoopCardPreview> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final widthFromCell = constraints.maxWidth / _stackWidthFactor;
        final widthFromHeight =
            constraints.maxHeight * storyCardCanvasAspectRatio;
        final cardWidth = math.min(
          _maximumCardWidth,
          math.min(widthFromCell, widthFromHeight),
        );
        final cardHeight = cardWidth / storyCardCanvasAspectRatio;

        if (cards.length == 1) {
          return Align(
            alignment: Alignment.center,
            child: _MonthStorySurface(
              card: cards.first,
              width: cardWidth,
              angle: 0,
            ),
          );
        }

        final stackWidth = cardWidth * _stackWidthFactor;

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: stackWidth,
            height: cardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: _MonthStorySurface(
                    card: cards.first,
                    width: cardWidth,
                    angle: -0.12,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _MonthStorySurface(
                    card: cards[1],
                    width: cardWidth,
                    angle: 0.14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MonthStorySurface extends StatelessWidget {
  const _MonthStorySurface({
    required this.card,
    required this.width,
    required this.angle,
  });

  final StoryLoopCardPreview card;
  final double width;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final previewUrl = card.previewUrl;
    final previewUri = previewUrl == null ? null : Uri.tryParse(previewUrl);
    final hasRemotePreview =
        previewUri != null &&
        previewUri.hasScheme &&
        (previewUri.scheme == 'http' || previewUri.scheme == 'https');

    return Transform.rotate(
      angle: angle,
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: storyCardCanvasAspectRatio,
          child: DecoratedBox(
            key: ValueKey('calendar-month-story-card-${card.id}'),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x28000000),
                  blurRadius: 3,
                  offset: Offset(0, 1.5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2.4),
              child: hasRemotePreview
                  ? Image.network(
                      previewUrl!,
                      fit: BoxFit.contain,
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
