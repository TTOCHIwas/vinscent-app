import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CalendarDetailDateHeader extends StatelessWidget {
  const CalendarDetailDateHeader({
    super.key,
    required this.date,
    this.height = baseExtent,
  });

  static const baseExtent = 76.0;
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
  final double height;

  static double resolveExtent(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final contentHeight =
        20 + (textScaler.scale(24) * 1.2) + 4 + (textScaler.scale(14) * 1.4);
    return math.max(baseExtent, contentHeight.ceilToDouble());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.month}월 ${date.day}일',
              style: AppTextStyles.calendarDetailDate,
            ),
            const SizedBox(height: 4),
            Text(
              '${date.year} · ${_weekdayLabels[date.weekday - 1]}',
              style: AppTextStyles.homeCharacterLabel.copyWith(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
