import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/date/app_date_policy.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../story_loops/data/story_loop_card_preview.dart';
import '../../../story_loops/data/story_loop_month_summary_day.dart';
import '../../data/couple_calendar_event.dart';
import '../calendar_expanded_cell_layout.dart';
import '../calendar_motion.dart';
import 'calendar_month_card_preview.dart';
import 'calendar_month_event_indicator.dart';

class CalendarMonthStoryCell extends StatelessWidget {
  const CalendarMonthStoryCell({
    super.key,
    required this.date,
    required this.textColor,
    required this.isSelected,
    this.isToday = false,
    required this.summary,
    this.events = const [],
    this.defaultEventLabel,
    this.expandedContentProgress = 0,
  });

  final DateTime date;
  final Color textColor;
  final bool isSelected;
  final bool isToday;
  final StoryLoopMonthSummaryDay? summary;
  final List<CoupleCalendarEvent> events;
  final String? defaultEventLabel;
  final double expandedContentProgress;

  static const _cellPadding = EdgeInsets.fromLTRB(3, 2, 3, 4);
  static const _maximumCompactEventArtworkSize = 18.0;
  static const _dateMarkerSize = 18.0;
  static const _eventHeaderGap = 1.0;
  static const _headerHeight = 20.0;

  @override
  Widget build(BuildContext context) {
    final visibleCards = _visibleCards(summary);
    final previewCacheExtent = math.max(
      1.0,
      MediaQuery.sizeOf(context).width / DateTime.daysPerWeek,
    );
    final resolvedExpandedProgress = math.min(
      1.0,
      math.max(0.0, expandedContentProgress),
    );
    final hasEventArtwork = events.any((event) => event.artwork != null);
    final contentIdentity = _contentIdentity(visibleCards, events);
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
            'calendar-month-story-cell-$displayMode-${formatCalendarDate(date)}',
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
                      key: isToday
                          ? ValueKey(
                              'calendar-today-indicator-${formatCalendarDate(date)}',
                            )
                          : null,
                      dimension: _dateMarkerSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.actionPrimary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday
                              ? Border.all(
                                  color: AppColors.attention,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: AppTypography.applyToStyle(
                              AppTextStyles.homeCharacterLabel.copyWith(
                                color: isSelected
                                    ? AppColors.textInverse
                                    : isToday
                                    ? AppColors.attention
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
                    if (defaultEventLabel case final label?) ...[
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
                    ] else ...[
                      const SizedBox(width: _eventHeaderGap),
                      Expanded(
                        child: _CalendarCellContentReveal(
                          transitionKey:
                              visibleCards.isNotEmpty && events.isNotEmpty
                              ? contentIdentity
                              : 'empty',
                          child: visibleCards.isEmpty || events.isEmpty
                              ? const SizedBox.shrink()
                              : hasEventArtwork && resolvedExpandedProgress >= 1
                              ? const SizedBox.shrink()
                              : Opacity(
                                  opacity: hasEventArtwork
                                      ? 1 - resolvedExpandedProgress
                                      : 1,
                                  child: CalendarMonthEventIndicator(
                                    date: date,
                                    events: events,
                                    artworkSize: eventArtworkSize,
                                    previewCacheExtent: previewCacheExtent,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _CalendarCellContentReveal(
                  key: ValueKey(
                    'calendar-cell-content-transition-${formatCalendarDate(date)}',
                  ),
                  transitionKey: contentIdentity,
                  child: _CalendarCellContent(
                    date: date,
                    events: events,
                    expandedContentProgress: resolvedExpandedProgress,
                    cards: visibleCards,
                    previewCacheExtent: previewCacheExtent,
                  ),
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

  String _contentIdentity(
    List<StoryLoopCardPreview> cards,
    List<CoupleCalendarEvent> events,
  ) {
    final cardParts =
        cards
            .map((card) => '${card.id}:${card.previewPath}')
            .toList(growable: false)
          ..sort();
    final eventParts =
        events
            .map((event) => '${event.id}:${event.revision}')
            .toList(growable: false)
          ..sort();
    return 'cards=${cardParts.join(',')}|events=${eventParts.join(',')}';
  }
}

class _CalendarCellContentReveal extends StatelessWidget {
  const _CalendarCellContentReveal({
    super.key,
    required this.transitionKey,
    required this.child,
  });

  final Object transitionKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: animationsDisabled
          ? Duration.zero
          : calendarCellContentRevealDuration,
      switchInCurve: calendarContentRevealCurve,
      switchOutCurve: calendarContentRevealCurve,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: ValueKey(transitionKey), child: child),
    );
  }
}

class _CalendarCellContent extends StatelessWidget {
  const _CalendarCellContent({
    required this.date,
    required this.events,
    required this.expandedContentProgress,
    required this.cards,
    required this.previewCacheExtent,
  });

  final DateTime date;
  final List<CoupleCalendarEvent> events;
  final double expandedContentProgress;
  final List<StoryLoopCardPreview> cards;
  final double previewCacheExtent;

  @override
  Widget build(BuildContext context) {
    final progress = math.min(1.0, math.max(0.0, expandedContentProgress));
    final artworkEvents =
        events.where((event) => event.artwork != null).toList(growable: false)
          ..sort((left, right) => left.title.compareTo(right.title));

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.biggest;
        final expandedLayout = CalendarExpandedCellLayout.resolve(
          size: cellSize,
          cardCount: cards.length,
          artworkCount: artworkEvents.length,
        );

        if (progress <= 0 || (artworkEvents.isEmpty && cards.isEmpty)) {
          return _buildCompactContent(
            cellSize: cellSize,
            expandedLayout: expandedLayout,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            if (cards.isEmpty && progress < 1)
              Opacity(
                opacity: 1 - progress,
                child: CalendarMonthEventIndicator(
                  date: date,
                  events: events,
                  artworkSize: calendarMonthCompactPreviewSize,
                  previewCacheExtent: previewCacheExtent,
                ),
              ),
            if (artworkEvents.isNotEmpty)
              Opacity(
                opacity: progress,
                child: CalendarExpandedEventArtworkLayer(
                  date: date,
                  events: artworkEvents,
                  totalEventCount: events.length,
                  layout: expandedLayout,
                  previewCacheExtent: previewCacheExtent,
                ),
              ),
            if (cards.isNotEmpty)
              CalendarMonthCardPreview(
                cards: cards,
                cellSize: cellSize,
                expandedLayout: expandedLayout,
                previewCacheExtent: previewCacheExtent,
                expandedProgress: progress,
              ),
          ],
        );
      },
    );
  }

  Widget _buildCompactContent({
    required Size cellSize,
    required CalendarExpandedCellLayout expandedLayout,
  }) {
    if (cards.isEmpty) {
      if (events.isEmpty) {
        return const SizedBox.expand();
      }

      return CalendarMonthEventIndicator(
        date: date,
        events: events,
        artworkSize: calendarMonthCompactPreviewSize,
        previewCacheExtent: previewCacheExtent,
      );
    }

    return CalendarMonthCardPreview(
      cards: cards,
      cellSize: cellSize,
      expandedLayout: expandedLayout,
      previewCacheExtent: previewCacheExtent,
    );
  }
}
