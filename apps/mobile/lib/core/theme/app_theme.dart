import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static const _lightColorScheme = ColorScheme.light(
    primary: AppColors.actionPrimary,
    onPrimary: AppColors.textInverse,
    primaryContainer: AppColors.actionDisabled,
    onPrimaryContainer: AppColors.textPrimary,
    secondary: AppColors.textMuted,
    onSecondary: AppColors.textInverse,
    secondaryContainer: AppColors.actionDisabled,
    onSecondaryContainer: AppColors.textPrimary,
    error: AppColors.recordingActive,
    onError: AppColors.textInverse,
    surface: AppColors.background,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.wireframeBorder,
    outlineVariant: AppColors.actionDisabled,
    inverseSurface: AppColors.actionPrimary,
    onInverseSurface: AppColors.textInverse,
    inversePrimary: AppColors.textInverse,
    surfaceTint: Colors.transparent,
  );

  static const _darkSurface = Color(0xFF1F1B1D);
  static const _darkColorScheme = ColorScheme.dark(
    primary: AppColors.white,
    onPrimary: AppColors.textPrimary,
    primaryContainer: Color(0xFF343034),
    onPrimaryContainer: AppColors.white,
    secondary: Color(0xFFB9B2B5),
    onSecondary: AppColors.textPrimary,
    secondaryContainer: Color(0xFF343034),
    onSecondaryContainer: AppColors.white,
    error: AppColors.recordingActive,
    onError: AppColors.textInverse,
    surface: _darkSurface,
    onSurface: AppColors.white,
    onSurfaceVariant: Color(0xFFB9B2B5),
    outline: Color(0xFF6B6367),
    outlineVariant: Color(0xFF343034),
    inverseSurface: AppColors.white,
    onInverseSurface: AppColors.textPrimary,
    inversePrimary: AppColors.actionPrimary,
    surfaceTint: Colors.transparent,
  );

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightColorScheme,
      typography: _typographyFor(_lightColorScheme),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      typography: _typographyFor(_darkColorScheme),
      scaffoldBackgroundColor: _darkSurface,
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }

  static Typography _typographyFor(ColorScheme colorScheme) {
    return AppTypography.applyToTypography(
      Typography.material2021(
        platform: defaultTargetPlatform,
        colorScheme: colorScheme,
      ),
    );
  }
}
