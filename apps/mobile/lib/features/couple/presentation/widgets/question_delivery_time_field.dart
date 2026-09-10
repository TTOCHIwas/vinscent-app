import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/question_delivery_time.dart';

class QuestionDeliveryTimeField extends StatelessWidget {
  const QuestionDeliveryTimeField({
    super.key,
    required this.selectedTime,
    required this.onTap,
  });

  final QuestionDeliveryTime selectedTime;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '질문 받을 시간 선택',
      value: selectedTime.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('question-delivery-time-field'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.formSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedTime.label,
                    style: AppTextStyles.homeBodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
