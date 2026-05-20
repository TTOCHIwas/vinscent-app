import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const onboardingTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 34 / 24,
    letterSpacing: 0,
  );

  static const onboardingInput = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 30 / 22,
    letterSpacing: 0,
  );

  static const onboardingHint = TextStyle(
    color: AppColors.textPlaceholder,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    letterSpacing: 0,
  );

  static const onboardingButton = TextStyle(
    color: AppColors.textInverse,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
    letterSpacing: 0,
  );

  static const socialButton = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    letterSpacing: 0,
  );

  static const logoLabel = TextStyle(
    color: AppColors.logoBackground,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );
}
