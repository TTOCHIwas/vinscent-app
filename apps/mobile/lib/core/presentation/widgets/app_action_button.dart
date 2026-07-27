import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'app_action_tone.dart';

class AppActionButton extends StatelessWidget {
  const AppActionButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.isLoading = false,
    this.tone = AppActionTone.neutral,
  });

  final String label;
  final bool enabled;
  final bool isLoading;
  final AppActionTone tone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && !isLoading && onPressed != null;
    final isSecondary = tone == AppActionTone.secondary;
    final activeBackgroundColor = switch (tone) {
      AppActionTone.neutral => AppColors.actionPrimary,
      AppActionTone.brand => AppColors.brandAction,
      AppActionTone.secondary => AppColors.background,
    };
    final activeContentColor = switch (tone) {
      AppActionTone.neutral => AppColors.textInverse,
      AppActionTone.brand => AppColors.onBrandAction,
      AppActionTone.secondary => AppColors.textPrimary,
    };
    final backgroundColor = isSecondary || isEnabled
        ? activeBackgroundColor
        : AppColors.actionDisabled;
    final contentColor = isSecondary || isEnabled
        ? activeContentColor
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
          overlayColor: tone == AppActionTone.brand
              ? const WidgetStatePropertyAll(AppColors.brandPressed)
              : null,
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
