import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/date/app_date_policy.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/couple_calendar_event.dart';
import '../calendar_expanded_cell_layout.dart';
import 'calendar_event_artwork.dart';

class CalendarMonthEventIndicator extends StatelessWidget {
  const CalendarMonthEventIndicator({
    super.key,
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

class CalendarExpandedEventArtworkLayer extends StatelessWidget {
  const CalendarExpandedEventArtworkLayer({
    super.key,
    required this.date,
    required this.events,
    required this.totalEventCount,
    required this.layout,
  });

  final DateTime date;
  final List<CoupleCalendarEvent> events;
  final int totalEventCount;
  final CalendarExpandedCellLayout layout;

  @override
  Widget build(BuildContext context) {
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
            child: _CalendarEventArtworkIndicator(
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
          key: ValueKey('calendar-event-overflow-${formatCalendarDate(date)}'),
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
