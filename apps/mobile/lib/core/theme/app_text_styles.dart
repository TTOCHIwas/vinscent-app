import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTextStyles {
  static const _tracking13 = 13 * AppTypography.letterSpacingRatio;
  static const _tracking14 = 14 * AppTypography.letterSpacingRatio;
  static const _tracking16 = 16 * AppTypography.letterSpacingRatio;
  static const _tracking18 = 18 * AppTypography.letterSpacingRatio;
  static const _tracking20 = 20 * AppTypography.letterSpacingRatio;
  static const _tracking22 = 22 * AppTypography.letterSpacingRatio;
  static const _tracking24 = 24 * AppTypography.letterSpacingRatio;

  static const shellTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 22 / 18,
    letterSpacing: _tracking18,
  );

  static const shellNavigation = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 20 / 16,
    letterSpacing: _tracking16,
  );

  static const homeBody = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: AppTypography.bodyLineHeight,
    letterSpacing: _tracking16,
  );

  static const homeBodyMedium = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: AppTypography.bodyLineHeight,
    letterSpacing: _tracking16,
  );

  static const homeQuestionBubble = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: AppTypography.bodyLineHeight,
    letterSpacing: _tracking16,
  );

  static const shellDayCount = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: _tracking24,
  );

  static const homeCharacterLabel = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: AppTypography.bodyLineHeight,
    letterSpacing: _tracking14,
  );

  static const onboardingTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 34 / 24,
    letterSpacing: _tracking24,
  );

  static const onboardingInput = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 30 / 22,
    letterSpacing: _tracking22,
  );

  static const onboardingHint = TextStyle(
    color: AppColors.textPlaceholder,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    letterSpacing: _tracking14,
  );

  static const onboardingButton = TextStyle(
    color: AppColors.textInverse,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
    letterSpacing: _tracking16,
  );

  static const socialButton = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    letterSpacing: _tracking16,
  );

  static const logoLabel = TextStyle(
    color: AppColors.logoBackground,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: _tracking16,
  );

  static const sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    letterSpacing: _tracking18,
  );

  static const pageTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
    letterSpacing: _tracking20,
  );

  static const compactError = TextStyle(
    color: Colors.redAccent,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 18 / 13,
    letterSpacing: _tracking13,
  );

  static const drawingToolLabel = TextStyle(
    color: Colors.white,
    fontSize: 13,
    height: 18 / 13,
    letterSpacing: _tracking13,
  );

  static const storyEditorTitle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 20 / 16,
    letterSpacing: _tracking16,
  );
}
