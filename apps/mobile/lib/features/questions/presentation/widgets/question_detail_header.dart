import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class QuestionDetailHeader extends StatelessWidget {
  const QuestionDetailHeader({
    super.key,
    required this.onBackPressed,
    this.assignedDate,
    this.action,
  });

  static const height = 56.0;

  final DateTime? assignedDate;
  final VoidCallback onBackPressed;
  final Widget? action;

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
              child: AppBackButton(
                onPressed: onBackPressed,
                color: AppColors.textPrimary,
                tooltip: '뒤로가기',
              ),
            ),
          ),
          if (assignedDate != null)
            Text(
              _formatQuestionDate(assignedDate),
              style: AppTextStyles.pageTitle,
            ),
          if (action case final action?)
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(child: action),
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
