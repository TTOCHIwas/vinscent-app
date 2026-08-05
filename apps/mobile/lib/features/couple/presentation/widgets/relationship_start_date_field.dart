import 'package:flutter/material.dart';

import '../../../../core/assets/app_icons.dart';
import '../../../../core/presentation/widgets/app_svg_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class RelationshipStartDateField extends StatelessWidget {
  const RelationshipStartDateField({
    super.key,
    required this.selectedDate,
    required this.onTap,
  });

  final DateTime? selectedDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selectedDate = this.selectedDate;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '만난 날 선택',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('relationship-start-date-field'),
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
                const AppSvgIcon(
                  AppIcons.calendar,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedDate == null ? '날짜 선택' : _formatDate(selectedDate),
                    style: AppTextStyles.homeBodyMedium.copyWith(
                      color: selectedDate == null
                          ? AppColors.textPlaceholder
                          : AppColors.textPrimary,
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

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }
}
