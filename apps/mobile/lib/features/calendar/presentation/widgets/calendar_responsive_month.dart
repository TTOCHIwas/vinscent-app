import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date/app_date_policy.dart';
import '../../../../core/presentation/widgets/app_horizontal_page_transition.dart';
import '../../../../core/presentation/widgets/app_horizontal_swipe_region.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../story_loops/application/story_loop_month_summary_provider.dart';
import '../../../story_loops/data/story_loop_month_summary_day.dart';
import '../../application/couple_default_calendar_event_resolver.dart';
import '../../application/couple_calendar_event_provider.dart';
import '../../data/calendar_cell_preview_mode.dart';
import '../../data/couple_calendar_event.dart';
import '../../data/couple_member_birthday.dart';
import '../calendar_month_layout_metrics.dart';
import 'calendar_detail_date_header.dart';
import 'calendar_month_story_cell.dart';

class CalendarResponsiveMonth extends ConsumerWidget {
  const CalendarResponsiveMonth({
    super.key,
    required this.visibleMonth,
    required this.relationshipStartDate,
    required this.selectedDate,
    required this.selectedDefaultEvents,
    required this.memberBirthdays,
    required this.calendarTransitionKey,
    required this.calendarTransitionDirection,
    required this.detailTransitionKey,
    required this.detailTransitionDirection,
    required this.onDatePressed,
    required this.metrics,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.onDetailSwipeRight,
    required this.onDetailSwipeLeft,
    required this.detailHeaderExtent,
    required this.previewMode,
  });

  final DateTime visibleMonth;
  final DateTime relationshipStartDate;
  final DateTime? selectedDate;
  final List<CoupleDefaultCalendarEventOccurrence> selectedDefaultEvents;
  final List<CoupleMemberBirthday> memberBirthdays;
  final Object calendarTransitionKey;
  final AppHorizontalPageDirection calendarTransitionDirection;
  final Object detailTransitionKey;
  final AppHorizontalPageDirection detailTransitionDirection;
  final ValueChanged<DateTime> onDatePressed;
  final CalendarMonthLayoutMetrics metrics;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final VoidCallback onDetailSwipeRight;
  final VoidCallback onDetailSwipeLeft;
  final double detailHeaderExtent;
  final CalendarCellPreviewMode? previewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryByDate = previewMode?.includesCards == true
        ? ref
              .watch(storyLoopMonthSummaryProvider(visibleMonth))
              .maybeWhen(
                data: (entries) => {
                  for (final entry in entries)
                    calendarDateOnly(entry.coupleDate): entry,
                },
                orElse: () => const <DateTime, StoryLoopMonthSummaryDay>{},
              )
        : const <DateTime, StoryLoopMonthSummaryDay>{};
    final eventsByDate = <DateTime, List<CoupleCalendarEvent>>{};
    if (previewMode?.includesEvents == true) {
      final calendarEvents = ref.watch(
        coupleCalendarEventMonthProvider(visibleMonth),
      );
      for (final event
          in calendarEvents.asData?.value ?? const <CoupleCalendarEvent>[]) {
        eventsByDate
            .putIfAbsent(calendarDateOnly(event.occurrenceDate), () => [])
            .add(event);
      }
    }
    final defaultEventLabels = <DateTime, String>{};
    const defaultEventResolver = CoupleDefaultCalendarEventResolver();
    for (final date in _calendarDays(visibleMonth)) {
      final occurrences = defaultEventResolver.resolve(
        relationshipStartDate: relationshipStartDate,
        date: date,
        birthdays: memberBirthdays,
      );
      if (occurrences.isNotEmpty) {
        defaultEventLabels[calendarDateOnly(date)] = occurrences.first.label;
      }
    }

    return SliverPersistentHeader(
      pinned: true,
      delegate: _CalendarMonthDelegate(
        visibleMonth: visibleMonth,
        relationshipStartDate: relationshipStartDate,
        selectedDate: selectedDate,
        selectedDefaultEvents: selectedDefaultEvents,
        calendarTransitionKey: calendarTransitionKey,
        calendarTransitionDirection: calendarTransitionDirection,
        detailTransitionKey: detailTransitionKey,
        detailTransitionDirection: detailTransitionDirection,
        summaryByDate: summaryByDate,
        eventsByDate: eventsByDate,
        defaultEventLabels: defaultEventLabels,
        onDatePressed: onDatePressed,
        metrics: metrics,
        onSwipeRight: onSwipeRight,
        onSwipeLeft: onSwipeLeft,
        onDetailSwipeRight: onDetailSwipeRight,
        onDetailSwipeLeft: onDetailSwipeLeft,
        detailHeaderExtent: detailHeaderExtent,
      ),
    );
  }
}

class _CalendarMonthDelegate extends SliverPersistentHeaderDelegate {
  _CalendarMonthDelegate({
    required this.visibleMonth,
    required this.relationshipStartDate,
    required this.selectedDate,
    required this.selectedDefaultEvents,
    required this.calendarTransitionKey,
    required this.calendarTransitionDirection,
    required this.detailTransitionKey,
    required this.detailTransitionDirection,
    required this.summaryByDate,
    required this.eventsByDate,
    required this.defaultEventLabels,
    required this.onDatePressed,
    required this.metrics,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.onDetailSwipeRight,
    required this.onDetailSwipeLeft,
    required this.detailHeaderExtent,
  });

  static const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];
  static const _topPadding = 8.0;
  static const _weekdayHeight = 20.0;
  static const _weekdayGridGap = 8.0;
  static const _columnGap = 4.0;

  final DateTime visibleMonth;
  final DateTime relationshipStartDate;
  final DateTime? selectedDate;
  final List<CoupleDefaultCalendarEventOccurrence> selectedDefaultEvents;
  final Object calendarTransitionKey;
  final AppHorizontalPageDirection calendarTransitionDirection;
  final Object detailTransitionKey;
  final AppHorizontalPageDirection detailTransitionDirection;
  final Map<DateTime, StoryLoopMonthSummaryDay> summaryByDate;
  final Map<DateTime, List<CoupleCalendarEvent>> eventsByDate;
  final Map<DateTime, String> defaultEventLabels;
  final ValueChanged<DateTime> onDatePressed;
  final CalendarMonthLayoutMetrics metrics;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final VoidCallback onDetailSwipeRight;
  final VoidCallback onDetailSwipeLeft;
  final double detailHeaderExtent;

  @override
  double get maxExtent => metrics.expandedExtent + detailHeaderExtent;

  @override
  double get minExtent => metrics.weeklyExtent + detailHeaderExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final values = metrics.resolve(shrinkOffset);
    final days = _calendarDays(visibleMonth);
    final selectedRow = _selectedRow(days);
    final rowPitch = values.rowHeight + values.rowGap;
    final gridTranslation = -(selectedRow * rowPitch * values.collapseProgress);
    final currentExtent = (maxExtent - shrinkOffset).clamp(
      minExtent,
      maxExtent,
    );
    final calendarExtent = currentExtent - detailHeaderExtent;

    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          SizedBox(
            height: calendarExtent,
            child: AppHorizontalSwipeRegion(
              key: const Key('calendar-month-swipe-region'),
              onSwipeRight: onSwipeRight,
              onSwipeLeft: onSwipeLeft,
              child: _buildMonthSurface(
                values: values,
                days: days,
                rowPitch: rowPitch,
                gridTranslation: gridTranslation,
              ),
            ),
          ),
          SizedBox(
            height: detailHeaderExtent,
            child: AppHorizontalSwipeRegion(
              key: const Key('calendar-detail-date-swipe-region'),
              onSwipeRight: onDetailSwipeRight,
              onSwipeLeft: onDetailSwipeLeft,
              child: AppHorizontalPageTransition(
                key: const Key('calendar-detail-header-transition'),
                transitionKey: detailTransitionKey,
                direction: detailTransitionDirection,
                child: selectedDate == null
                    ? const SizedBox.expand()
                    : CalendarDetailDateHeader(
                        date: selectedDate!,
                        defaultEvents: selectedDefaultEvents,
                        height: detailHeaderExtent,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSurface({
    required CalendarMonthLayoutValues values,
    required List<DateTime> days,
    required double rowPitch,
    required double gridTranslation,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth - (values.horizontalPadding * 2);
        final cellWidth =
            (availableWidth - (_columnGap * 6)) / DateTime.daysPerWeek;
        final gridTop = _topPadding + _weekdayHeight + _weekdayGridGap;

        return ClipRect(
          child: Stack(
            children: [
              for (var index = 0; index < DateTime.daysPerWeek; index++)
                Positioned(
                  left:
                      values.horizontalPadding +
                      (index * (cellWidth + _columnGap)),
                  top: _topPadding,
                  width: cellWidth,
                  height: _weekdayHeight,
                  child: _WeekdayCell(label: _weekdayLabels[index]),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: gridTop,
                bottom: 0,
                child: AppHorizontalPageTransition(
                  key: const Key('calendar-date-grid-transition'),
                  transitionKey: calendarTransitionKey,
                  direction: calendarTransitionDirection,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        for (var index = 0; index < days.length; index++)
                          Positioned(
                            left:
                                values.horizontalPadding +
                                ((index % DateTime.daysPerWeek) *
                                    (cellWidth + _columnGap)),
                            top:
                                ((index ~/ DateTime.daysPerWeek) * rowPitch) +
                                gridTranslation,
                            width: cellWidth,
                            height: values.rowHeight,
                            child: _DateCell(
                              date: days[index],
                              isCurrentMonth: isSameCalendarMonth(
                                days[index],
                                visibleMonth,
                              ),
                              isEnabled: _isEnabled(days[index]),
                              isSelected:
                                  selectedDate != null &&
                                  isSameCalendarDate(
                                    days[index],
                                    selectedDate!,
                                  ),
                              summary:
                                  summaryByDate[calendarDateOnly(days[index])],
                              events:
                                  eventsByDate[calendarDateOnly(days[index])] ??
                                  const [],
                              defaultEventLabel:
                                  defaultEventLabels[calendarDateOnly(
                                    days[index],
                                  )],
                              expandedContentProgress:
                                  values.expandedContentProgress,
                              onPressed: () => onDatePressed(days[index]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _selectedRow(List<DateTime> days) {
    final selected = selectedDate;
    if (selected != null && isSameCalendarMonth(selected, visibleMonth)) {
      final index = days.indexWhere(
        (date) => isSameCalendarDate(date, selected),
      );
      if (index >= 0) {
        return index ~/ DateTime.daysPerWeek;
      }
    }

    final monthStartIndex = days.indexWhere(
      (date) => isSameCalendarDate(date, calendarMonthOnly(visibleMonth)),
    );
    return monthStartIndex < 0 ? 0 : monthStartIndex ~/ DateTime.daysPerWeek;
  }

  bool _isEnabled(DateTime date) {
    if (!isSameCalendarMonth(date, visibleMonth)) {
      return false;
    }
    return !calendarDateOnly(
      date,
    ).isBefore(calendarDateOnly(relationshipStartDate));
  }

  @override
  bool shouldRebuild(covariant _CalendarMonthDelegate oldDelegate) {
    return visibleMonth != oldDelegate.visibleMonth ||
        relationshipStartDate != oldDelegate.relationshipStartDate ||
        selectedDate != oldDelegate.selectedDate ||
        !_sameDefaultEvents(
          selectedDefaultEvents,
          oldDelegate.selectedDefaultEvents,
        ) ||
        summaryByDate != oldDelegate.summaryByDate ||
        eventsByDate != oldDelegate.eventsByDate ||
        defaultEventLabels != oldDelegate.defaultEventLabels ||
        metrics.expandedExtent != oldDelegate.metrics.expandedExtent ||
        metrics.standardExtent != oldDelegate.metrics.standardExtent ||
        detailHeaderExtent != oldDelegate.detailHeaderExtent ||
        calendarTransitionKey != oldDelegate.calendarTransitionKey ||
        calendarTransitionDirection !=
            oldDelegate.calendarTransitionDirection ||
        detailTransitionKey != oldDelegate.detailTransitionKey ||
        detailTransitionDirection != oldDelegate.detailTransitionDirection;
  }
}

bool _sameDefaultEvents(
  List<CoupleDefaultCalendarEventOccurrence> left,
  List<CoupleDefaultCalendarEventOccurrence> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    final leftEvent = left[index];
    final rightEvent = right[index];
    if (leftEvent.kind != rightEvent.kind ||
        leftEvent.label != rightEvent.label ||
        leftEvent.date != rightEvent.date) {
      return false;
    }
  }
  return true;
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: AppTypography.applyToStyle(
          AppTextStyles.homeCharacterLabel.copyWith(
            color: const Color(0xFF8C8C8C),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isEnabled,
    required this.isSelected,
    required this.summary,
    required this.events,
    required this.defaultEventLabel,
    required this.expandedContentProgress,
    required this.onPressed,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isEnabled;
  final bool isSelected;
  final StoryLoopMonthSummaryDay? summary;
  final List<CoupleCalendarEvent> events;
  final String? defaultEventLabel;
  final double expandedContentProgress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: isEnabled,
      selected: isSelected,
      label: [
        '${date.day}일',
        ?defaultEventLabel,
        if (events.isNotEmpty) '일정 ${events.length}개',
        if ((summary?.cardCount ?? 0) > 0) '카드 ${summary!.cardCount}개',
      ].join(', '),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(4),
        child: CalendarMonthStoryCell(
          date: date,
          textColor: _textColor,
          isSelected: isSelected,
          summary: isCurrentMonth ? summary : null,
          events: isCurrentMonth ? events : const [],
          defaultEventLabel: isCurrentMonth ? defaultEventLabel : null,
          expandedContentProgress: expandedContentProgress,
        ),
      ),
    );
  }

  Color get _textColor {
    if (!isCurrentMonth || !isEnabled) {
      return const Color(0xFFC7C7C7);
    }
    return const Color(0xFF171717);
  }
}

List<DateTime> _calendarDays(DateTime visibleMonth) {
  final firstDay = calendarMonthOnly(visibleMonth);
  final sundayOffset = firstDay.weekday % DateTime.daysPerWeek;
  final startDate = firstDay.subtract(Duration(days: sundayOffset));
  return [
    for (var index = 0; index < 42; index++)
      startDate.add(Duration(days: index)),
  ];
}
