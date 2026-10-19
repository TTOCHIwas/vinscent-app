import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppInputStyle {
  static const focusColor = AppColors.actionPrimary;
  static const selectionColor = Color(0x26171717);
  static const surface = Color(0xFFF2F2F7);
  static const _darkSurface = Color(0xFF2C2C2E);
  static const textStyle = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 22 / 17,
    letterSpacing: 17 * AppTypography.letterSpacingRatio,
    color: AppColors.textPrimary,
  );
  static const _border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide.none,
  );
  static const _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: focusColor),
  );
  static const _errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: AppColors.recordingActive),
  );

  static const theme = InputDecorationThemeData(
    filled: true,
    fillColor: surface,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: TextStyle(
      color: AppColors.textMuted,
      fontSize: 17,
      fontWeight: FontWeight.w400,
      height: 22 / 17,
    ),
    border: _border,
    enabledBorder: _border,
    disabledBorder: _border,
    focusedBorder: _focusedBorder,
    errorBorder: _errorBorder,
    focusedErrorBorder: _errorBorder,
    errorMaxLines: 3,
  );

  static InputDecoration decoration({
    String? hintText,
    String? labelText,
    String? counterText,
    Widget? suffixIcon,
    TextStyle? hintStyle,
    Brightness brightness = Brightness.light,
  }) {
    final isDark = brightness == Brightness.dark;
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      counterText: counterText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? _darkSurface : surface,
      isDense: theme.isDense,
      contentPadding: theme.contentPadding,
      hintStyle:
          hintStyle ??
          textStyle.copyWith(
            color: isDark ? const Color(0xFFAEAEB2) : AppColors.textMuted,
          ),
      border: _border,
      enabledBorder: _border,
      disabledBorder: _border,
      focusedBorder: _focusedBorder,
      errorBorder: _errorBorder,
      focusedErrorBorder: _errorBorder,
      errorMaxLines: 3,
    );
  }

  static Brightness contrastingBrightness(Color foreground) =>
      _contrast(foreground, _darkSurface) > _contrast(foreground, surface)
      ? Brightness.dark
      : Brightness.light;

  static double _contrast(Color foreground, Color background) {
    final foregroundLuminance = Color.alphaBlend(
      foreground,
      background,
    ).computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    return (math.max(foregroundLuminance, backgroundLuminance) + 0.05) /
        (math.min(foregroundLuminance, backgroundLuminance) + 0.05);
  }
}
