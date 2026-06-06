import 'package:flutter/material.dart';

import '../../../../core/assets/app_icons.dart';
import '../../../../core/presentation/widgets/app_svg_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class BirthDateStep extends StatelessWidget {
  const BirthDateStep({
    super.key,
    required this.birthDate,
    required this.onTap,
  });

  final DateTime? birthDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = birthDate;
    final hasDate = selected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('생일을\n입력해 주세요.', style: AppTextStyles.onboardingTitle),
        const SizedBox(height: 54),
        Semantics(
          button: true,
          label: '생일 선택',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 56,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasDate ? _formatDate(selected) : 'YYYY-MM-DD',
                        style: AppTextStyles.onboardingInput.copyWith(
                          color: hasDate
                              ? AppColors.textPrimary
                              : AppColors.textPlaceholder,
                        ),
                      ),
                    ),
                    const AppSvgIcon(
                      AppIcons.calendar,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
