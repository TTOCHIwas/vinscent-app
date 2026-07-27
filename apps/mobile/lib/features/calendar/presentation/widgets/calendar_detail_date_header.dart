import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CalendarDetailDateHeader extends StatelessWidget {
  const CalendarDetailDateHeader({
    super.key,
    required this.date,
    this.anniversaryLabels = const [],
    this.height = baseExtent,
  });

  static const baseExtent = 76.0;
  static const _horizontalPadding = 20.0;
  static const _verticalPadding = 10.0;
  static const _dateLineGap = 4.0;
  static const _sectionGap = 8.0;
  static const _anniversaryRunSpacing = 2.0;
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
  final List<String> anniversaryLabels;
  final double height;

  static double resolveExtent(
    BuildContext context, {
    List<String> anniversaryLabels = const [],
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final dateContentHeight =
        (textScaler.scale(24) * 1.2) +
        _dateLineGap +
        (textScaler.scale(14) * 1.4);
    final anniversaryContentHeight = anniversaryLabels.isEmpty
        ? 0.0
        : (textScaler.scale(16) * 1.4 * anniversaryLabels.length) +
              (_anniversaryRunSpacing * (anniversaryLabels.length - 1));
    final bodyHeight =
        anniversaryLabels.isNotEmpty &&
            _usesStackedLayout(context, anniversaryLabels)
        ? dateContentHeight + _sectionGap + anniversaryContentHeight
        : math.max(dateContentHeight, anniversaryContentHeight);
    final contentHeight = (_verticalPadding * 2) + bodyHeight;
    return math.max(baseExtent, contentHeight.ceilToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final dateBlock = _DateBlock(date: date);
    final anniversaryBlock = _AnniversaryLabels(labels: anniversaryLabels);
    final usesStackedLayout = _usesStackedLayout(context, anniversaryLabels);

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
                    child: anniversaryBlock,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  dateBlock,
                  if (anniversaryLabels.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: anniversaryBlock,
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
    List<String> anniversaryLabels,
  ) {
    if (anniversaryLabels.isEmpty) {
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

class _AnniversaryLabels extends StatelessWidget {
  const _AnniversaryLabels({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      key: const Key('calendar-detail-anniversary-labels'),
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: CalendarDetailDateHeader._anniversaryRunSpacing,
      children: [
        for (final label in labels)
          Text(label, style: AppTextStyles.homeBodyMedium),
      ],
    );
  }
}
