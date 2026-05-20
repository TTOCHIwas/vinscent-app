import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class OnboardingActionButton extends StatelessWidget {
  const OnboardingActionButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final bool enabled;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && !isLoading && onPressed != null;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: isEnabled ? AppColors.actionPrimary : AppColors.actionDisabled,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textInverse,
                    ),
                  )
                : Text(
                    label,
                    style: AppTextStyles.onboardingButton.copyWith(
                      color: isEnabled
                          ? AppColors.textInverse
                          : AppColors.actionDisabledContent,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
