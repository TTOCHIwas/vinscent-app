import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class RecordDateLabel extends StatelessWidget {
  const RecordDateLabel({super.key, required this.date, this.annotation});

  static const lineGap = 4.0;
  static const _weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  final DateTime date;
  final String? annotation;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: lineGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${date.month}월 ${date.day}일',
            style: AppTextStyles.calendarDetailDate,
          ),
          if (annotation case final text?)
            Text(
              text,
              style: AppTextStyles.homeCharacterLabel.copyWith(
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
      const SizedBox(height: lineGap),
      Text(
        '${date.year} · ${_weekdays[date.weekday - 1]}',
        style: AppTextStyles.homeCharacterLabel.copyWith(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
      ),
    ],
  );
}
