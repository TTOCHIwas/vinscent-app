import 'package:flutter/material.dart';

import '../../../../core/assets/app_icons.dart';
import '../../../../core/presentation/widgets/app_svg_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class BirthDateStep extends StatelessWidget {
  const BirthDateStep({
    super.key,
    required this.birthDate,
    required this.showEligibilityError,
    required this.onTap,
  });

  final DateTime? birthDate;
  final bool showEligibilityError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = birthDate;
    final hasDate = selected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('생일은 언제야?', style: AppTextStyles.onboardingTitle),
        const SizedBox(height: 8),
        Text(
          '생일은 둘의 캘린더에 기본 일정으로 표시돼',
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 32),
        Semantics(
          button: true,
          label: '생일 선택',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('onboarding-birth-date-field'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(6),
              child: Ink(
                decoration: BoxDecoration(
                  color: AppColors.formSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasDate ? _formatDate(selected) : 'YYYY-MM-DD',
                        style: AppTextStyles.homeBodyMedium.copyWith(
                          color: hasDate
                              ? AppColors.textPrimary
                              : AppColors.textPlaceholder,
                        ),
                      ),
                    ),
                    const AppSvgIcon(
                      AppIcons.calendar,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showEligibilityError) ...[
          const SizedBox(height: 8),
          const Text(
            '현재 이용 기준에 해당하지 않아 가입할 수 없어',
            style: AppTextStyles.compactError,
          ),
        ],
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
