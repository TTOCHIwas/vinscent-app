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
    this.showExpandedEventArtwork = false,
  });

  final DateTime date;
  final Color textColor;
  final bool isSelected;
  final StoryLoopMonthSummaryDay? summary;
  final List<CoupleCalendarEvent> events;
  final String? anniversaryLabel;
  final bool showExpandedEventArtwork;

  static const _cellPadding = EdgeInsets.fromLTRB(3, 2, 3, 4);
  static const _maximumEventArtworkSize = 18.0;
  static const _dateMarkerSize = 18.0;
  static const _eventHeaderGap = 1.0;
  static const _headerHeight = 20.0;

  @override
  Widget build(BuildContext context) {
    final visibleCards = _visibleCards(summary);
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
            _maximumEventArtworkSize,
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
                        events.isNotEmpty &&
                        !showExpandedEventArtwork) ...[
                      const SizedBox(width: _eventHeaderGap),
                      Expanded(
                        child: _CalendarEventIndicator(
                          date: date,
                          events: events,
                          artworkSize: eventArtworkSize,
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
                  showExpandedEventArtwork: showExpandedEventArtwork,
                  eventArtworkSize: eventArtworkSize,
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
    required this.showExpandedEventArtwork,
    required this.eventArtworkSize,
    required this.cards,
  });

  final DateTime date;
  final List<CoupleCalendarEvent> events;
  final bool showExpandedEventArtwork;
  final double eventArtworkSize;
  final List<StoryLoopCardPreview> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      if (events.isEmpty) {
        return const _MonthStoryPreview(cards: []);
      }

      return _CalendarEventIndicator(
        date: date,
        events: events,
        artworkSize: eventArtworkSize,
      );
    }

    if (events.isEmpty || !showExpandedEventArtwork || eventArtworkSize <= 0) {
      return _MonthStoryPreview(cards: cards);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: eventArtworkSize,
          child: _CalendarEventIndicator(
            date: date,
            events: events,
            artworkSize: eventArtworkSize,
          ),
        ),
        Expanded(child: _MonthStoryPreview(cards: cards)),
      ],
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
    final event = sortedEvents.first;
    final overflowCount = events.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final widthLimit = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : artworkSize;
        final heightLimit = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : artworkSize;
        final resolvedArtworkSize = math.max(
          0.0,
          math.min(artworkSize, math.min(widthLimit, heightLimit)),
        );

        return Align(
          alignment: Alignment.center,
          child: _CalendarEventArtworkIndicator(
            date: date,
            event: event,
            size: resolvedArtworkSize,
            overflowCount: overflowCount,
          ),
        );
      },
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
