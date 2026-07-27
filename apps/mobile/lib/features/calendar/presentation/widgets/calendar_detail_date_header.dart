import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/couple_default_calendar_event_resolver.dart';

class CalendarDetailDateHeader extends StatelessWidget {
  const CalendarDetailDateHeader({
    super.key,
    required this.date,
    this.defaultEvents = const [],
    this.height = baseExtent,
  });

  static const baseExtent = 76.0;
  static const _horizontalPadding = 20.0;
  static const _verticalPadding = 10.0;
  static const _dateLineGap = 4.0;
  static const _sectionGap = 8.0;
  static const _defaultEventRunSpacing = 4.0;
  static const _defaultEventIconSize = 22.0;
  static const _stackedLayoutWidth = 220.0;
  static const _weekdayLabels = [
    '월요일',
    '화요일',
    '수요일',
    '목요일',
    '금요일',
    '토요일',
    '일요일',
  ];

  final DateTime date;
  final List<CoupleDefaultCalendarEventOccurrence> defaultEvents;
  final double height;

  static double resolveExtent(
    BuildContext context, {
    List<CoupleDefaultCalendarEventOccurrence> defaultEvents = const [],
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final dateContentHeight =
        (textScaler.scale(24) * 1.2) +
        _dateLineGap +
        (textScaler.scale(14) * 1.4);
    final defaultEventLineHeight = math.max(
      textScaler.scale(20) * 1.4,
      _defaultEventIconSize,
    );
    final defaultEventContentHeight = defaultEvents.isEmpty
        ? 0.0
        : (defaultEventLineHeight * defaultEvents.length) +
              (_defaultEventRunSpacing * (defaultEvents.length - 1));
    final bodyHeight =
        defaultEvents.isNotEmpty && _usesStackedLayout(context, defaultEvents)
        ? dateContentHeight + _sectionGap + defaultEventContentHeight
        : math.max(dateContentHeight, defaultEventContentHeight);
    final contentHeight = (_verticalPadding * 2) + bodyHeight;
    return math.max(baseExtent, contentHeight.ceilToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final dateBlock = _DateBlock(date: date);
    final defaultEventBlock = _DefaultEvents(events: defaultEvents);
    final usesStackedLayout = _usesStackedLayout(context, defaultEvents);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
        child: usesStackedLayout
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  dateBlock,
                  const SizedBox(height: _sectionGap),
                  Align(
                    alignment: Alignment.centerRight,
                    child: defaultEventBlock,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  dateBlock,
                  if (defaultEvents.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: defaultEventBlock,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  static bool _usesStackedLayout(
    BuildContext context,
    List<CoupleDefaultCalendarEventOccurrence> defaultEvents,
  ) {
    if (defaultEvents.isEmpty) {
      return false;
    }
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final availableWidth =
        MediaQuery.sizeOf(context).width - (_horizontalPadding * 2);
    return availableWidth / math.max(1, textScale) < _stackedLayoutWidth;
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${date.month}월 ${date.day}일',
          style: AppTextStyles.calendarDetailDate,
        ),
        const SizedBox(height: CalendarDetailDateHeader._dateLineGap),
        Text(
          '${date.year} · '
          '${CalendarDetailDateHeader._weekdayLabels[date.weekday - 1]}',
          style: AppTextStyles.homeCharacterLabel.copyWith(
            color: AppColors.textMuted,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _DefaultEvents extends StatelessWidget {
  const _DefaultEvents({required this.events});

  final List<CoupleDefaultCalendarEventOccurrence> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      key: const Key('calendar-detail-default-event-labels'),
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: CalendarDetailDateHeader._defaultEventRunSpacing,
      children: [for (final event in events) _DefaultEvent(event: event)],
    );
  }
}

class _DefaultEvent extends StatelessWidget {
  const _DefaultEvent({required this.event});

  final CoupleDefaultCalendarEventOccurrence event;

  @override
  Widget build(BuildContext context) {
    final icon = switch (event.kind) {
      CoupleDefaultCalendarEventKind.relationshipAnniversary =>
        LucideIcons.calendarHeart,
      CoupleDefaultCalendarEventKind.birthday => LucideIcons.cakeSlice,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: CalendarDetailDateHeader._defaultEventIconSize,
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: 6),
        Text(event.label, style: AppTextStyles.pageTitle),
      ],
    );
  }
}
