import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class QuestionDetailHeader extends StatelessWidget {
  const QuestionDetailHeader({
    super.key,
    required this.onBackPressed,
    this.assignedDate,
  });

  static const height = 56.0;

  final DateTime? assignedDate;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    final assignedDate = this.assignedDate;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                onPressed: onBackPressed,
                icon: const Icon(Icons.chevron_left),
                color: AppColors.textPrimary,
                iconSize: 28,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                tooltip: '뒤로가기',
              ),
            ),
          ),
          if (assignedDate != null)
            Text(
              _formatQuestionDate(assignedDate),
              style: AppTextStyles.shellTitle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }
}

String _formatQuestionDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month월 $day일';
}
