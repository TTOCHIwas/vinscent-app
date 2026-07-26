import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_sized_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../story_loops/data/story_loop_card_preview.dart';
import '../../../story_loops/data/story_card_scene.dart';
import '../../../story_loops/data/story_loop_month_summary_day.dart';
import '../../data/couple_calendar_event.dart';
import '../calendar_expanded_cell_layout.dart';
import 'calendar_event_artwork.dart';

const _maximumCompactCalendarCellPreviewSize = 48.0;

class CalendarMonthStoryCell extends StatelessWidget {
  const CalendarMonthStoryCell({
    super.key,
    required this.date,
    required this.textColor,
    required this.isSelected,
    required this.summary,
    this.events = const [],
    this.anniversaryLabel,
    this.expandedContentProgress = 0,
  });

  final DateTime date;
  final Color textColor;
  final bool isSelected;
  final StoryLoopMonthSummaryDay? summary;
  final List<CoupleCalendarEvent> events;
  final String? anniversaryLabel;
  final double expandedContentProgress;

  static const _cellPadding = EdgeInsets.fromLTRB(3, 2, 3, 4);
  static const _maximumCompactEventArtworkSize = 18.0;
  static const _dateMarkerSize = 18.0;
  static const _eventHeaderGap = 1.0;
  static const _headerHeight = 20.0;

  @override
  Widget build(BuildContext context) {
    final visibleCards = _visibleCards(summary);
    final resolvedExpandedProgress = math.min(
      1.0,
      math.max(0.0, expandedContentProgress),
    );
    final hasEventArtwork = events.any((event) => event.artwork != null);
    final displayMode = switch (visibleCards.length) {
      0 => 'empty',
      1 => 'single',
      _ => 'stacked',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final eventArtworkSize = math.max(
          0.0,
          math.min(
            _maximumCompactEventArtworkSize,
            constraints.maxWidth -
                _cellPadding.horizontal -
                _dateMarkerSize -
                _eventHeaderGap,
          ),
        );

        return Padding(
          key: ValueKey(
            'calendar-month-story-cell-$displayMode-${_calendarDateKey(date)}',
          ),
          padding: _cellPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _headerHeight,
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: _dateMarkerSize,
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
                    ] else if (visibleCards.isNotEmpty &&
                        events.isNotEmpty) ...[
                      const SizedBox(width: _eventHeaderGap),
                      Expanded(
                        child: hasEventArtwork && resolvedExpandedProgress >= 1
                            ? const SizedBox.shrink()
                            : Opacity(
                                opacity: hasEventArtwork
                                    ? 1 - resolvedExpandedProgress
                                    : 1,
                                child: _CalendarEventIndicator(
                                  date: date,
                                  events: events,
                                  artworkSize: eventArtworkSize,
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _CalendarCellContent(
                  date: date,
                  events: events,
                  expandedContentProgress: resolvedExpandedProgress,
                  cards: visibleCards,
                ),
              ),
            ],
          ),
        );
      },
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
    required this.expandedContentProgress,
    required this.cards,
  });

  final DateTime date;
  final List<CoupleCalendarEvent> events;
  final double expandedContentProgress;
  final List<StoryLoopCardPreview> cards;

  @override
  Widget build(BuildContext context) {
    final progress = math.min(1.0, math.max(0.0, expandedContentProgress));
    final artworkEvents =
        events.where((event) => event.artwork != null).toList(growable: false)
          ..sort((left, right) => left.title.compareTo(right.title));

    if (progress <= 0 || (artworkEvents.isEmpty && cards.isEmpty)) {
      return _buildCompactContent();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (cards.isEmpty && progress < 1)
          Opacity(
            opacity: 1 - progress,
            child: _CalendarEventIndicator(
              date: date,
              events: events,
              artworkSize: _maximumCompactCalendarCellPreviewSize,
            ),
          ),
        if (artworkEvents.isNotEmpty)
          Opacity(
            opacity: progress,
            child: _ExpandedCalendarEventArtworkLayer(
              date: date,
              events: artworkEvents,
              totalEventCount: events.length,
              cardCount: cards.length,
            ),
          ),
        if (cards.isNotEmpty)
          _MonthStoryPreview(
            cards: cards,
            expandedProgress: progress,
            artworkCount: artworkEvents.length,
          ),
      ],
    );
  }

  Widget _buildCompactContent() {
    if (cards.isEmpty) {
      if (events.isEmpty) {
        return const _MonthStoryPreview(cards: []);
      }

      return _CalendarEventIndicator(
        date: date,
        events: events,
        artworkSize: _maximumCompactCalendarCellPreviewSize,
      );
    }

    return _MonthStoryPreview(cards: cards);
  }
}

class _ExpandedCalendarEventArtworkLayer extends StatelessWidget {
  const _ExpandedCalendarEventArtworkLayer({
    required this.date,
    required this.events,
    required this.totalEventCount,
    required this.cardCount,
  });

  final DateTime date;
  final List<CoupleCalendarEvent> events;
  final int totalEventCount;
  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = CalendarExpandedCellLayout.resolve(
          size: constraints.biggest,
          cardCount: cardCount,
          artworkCount: events.length,
        );
        final visibleEvents = events
            .take(layout.visibleArtworkCount)
            .toList(growable: false);
        final overflowCount = totalEventCount - visibleEvents.length;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < visibleEvents.length; index++)
              Positioned(
                left: layout.artworkOrigin.dx + layout.artworkOffsets[index].dx,
                top: layout.artworkOrigin.dy + layout.artworkOffsets[index].dy,
                child: _ExpandedCalendarEventArtworkIndicator(
                  date: date,
                  event: visibleEvents[index],
                  size: layout.artworkSize,
                  overflowCount: index == visibleEvents.length - 1
                      ? overflowCount
                      : 0,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ExpandedCalendarEventArtworkIndicator extends StatelessWidget {
  const _ExpandedCalendarEventArtworkIndicator({
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
              child: _CalendarEventOverflowBadge(
                date: date,
                overflowCount: overflowCount,
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarEventIndicator extends StatelessWidget {
  const _CalendarEventIndicator({
    required this.date,
    required this.events,
    required this.artworkSize,
  });

  final DateTime date;
  final List<CoupleCalendarEvent> events;
  final double artworkSize;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

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
    final visibleEvent = sortedEvents.first;
    final overflowCount = events.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedArtworkSize = _resolveArtworkSize(
          constraints: constraints,
        );

        return Align(
          alignment: Alignment.center,
          child: _CalendarEventArtworkIndicator(
            date: date,
            event: visibleEvent,
            size: resolvedArtworkSize,
            overflowCount: overflowCount,
          ),
        );
      },
    );
  }

  double _resolveArtworkSize({required BoxConstraints constraints}) {
    final widthLimit = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : artworkSize;
    final heightLimit = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : artworkSize;
    return math.max(
      0,
      math.min(artworkSize, math.min(widthLimit, heightLimit)),
    );
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
              child: _CalendarEventOverflowBadge(
                date: date,
                overflowCount: overflowCount,
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarEventOverflowBadge extends StatelessWidget {
  const _CalendarEventOverflowBadge({
    required this.date,
    required this.overflowCount,
  });

  final DateTime date;
  final int overflowCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Text(
          '+$overflowCount',
          key: ValueKey('calendar-event-overflow-${_calendarDateKey(date)}'),
          style: AppTypography.applyToStyle(
            AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
              fontSize: 10,
              height: 1,
            ),
          ),
        ),
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
  const _MonthStoryPreview({
    required this.cards,
    this.expandedProgress = 0,
    this.artworkCount = 0,
  });

  static const _stackWidthFactor = 1.55;

  final List<StoryLoopCardPreview> cards;
  final double expandedProgress;
  final int artworkCount;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final progress = math.min(1.0, math.max(0.0, expandedProgress));
        final compactWidthFromCell = constraints.maxWidth / _stackWidthFactor;
        final compactWidthFromHeight =
            constraints.maxHeight * storyCardCanvasAspectRatio;
        final compactCardWidth = math.min(
          _maximumCompactCalendarCellPreviewSize,
          math.min(compactWidthFromCell, compactWidthFromHeight),
        );
        final expandedLayout = CalendarExpandedCellLayout.resolve(
          size: constraints.biggest,
          cardCount: cards.length,
          artworkCount: artworkCount,
        );
        final cardWidth =
            compactCardWidth +
            ((expandedLayout.cardWidth - compactCardWidth) * progress);
        final compactCardHeight = compactCardWidth / storyCardCanvasAspectRatio;
        final compactHorizontalOffset = cards.length == 2
            ? compactCardWidth * (_stackWidthFactor - 1)
            : 0.0;
        final compactGroupSize = Size(
          compactCardWidth + compactHorizontalOffset,
          compactCardHeight,
        );
        final compactOrigin = Offset(
          (constraints.maxWidth - compactGroupSize.width) / 2,
          (constraints.maxHeight - compactGroupSize.height) / 2,
        );
        final compactOffsets = cards.length == 2
            ? [Offset.zero, Offset(compactHorizontalOffset, 0)]
            : const [Offset.zero];

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < cards.length; index++)
              Positioned(
                left: _lerpCoordinate(
                  compactOrigin.dx + compactOffsets[index].dx,
                  expandedLayout.cardOrigin.dx +
                      expandedLayout.cardOffsets[index].dx,
                  progress,
                ),
                top: _lerpCoordinate(
                  compactOrigin.dy + compactOffsets[index].dy,
                  expandedLayout.cardOrigin.dy +
                      expandedLayout.cardOffsets[index].dy,
                  progress,
                ),
                child: _MonthStorySurface(
                  card: cards[index],
                  width: cardWidth,
                  angle: switch (index) {
                    0 when cards.length == 2 => -0.12,
                    1 => 0.14,
                    _ => 0,
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  double _lerpCoordinate(double start, double end, double progress) {
    return start + ((end - start) * progress);
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
    final height = width / storyCardCanvasAspectRatio;

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
              child: AppSizedNetworkImage(
                url: card.previewUrl,
                logicalSize: Size(width, height),
                fallbackBuilder: (_) => _MonthStoryPlaceholder(card: card),
              ),
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
