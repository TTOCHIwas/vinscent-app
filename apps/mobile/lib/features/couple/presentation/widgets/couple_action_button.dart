import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CoupleActionButton extends StatelessWidget {
  const CoupleActionButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
  });

  final String label;
  final bool enabled;
  final bool isLoading;
  final bool isSecondary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && !isLoading && onPressed != null;
    final backgroundColor = isSecondary
        ? AppColors.background
        : isEnabled
        ? AppColors.actionPrimary
        : AppColors.actionDisabled;
    final contentColor = isSecondary
        ? AppColors.textPrimary
        : isEnabled
        ? AppColors.textInverse
        : AppColors.actionDisabledContent;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isSecondary
              ? const BorderSide(color: AppColors.wireframeBorder)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: isLoading
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: contentColor,
                    ),
                  )
                : Text(
                    label,
                    style: AppTextStyles.onboardingButton.copyWith(
                      color: contentColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
