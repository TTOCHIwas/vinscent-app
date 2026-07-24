import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const bodyLineHeight = 1.4;
  static const letterSpacingRatio = -0.025;

  static double letterSpacingFor(double fontSize) {
    return fontSize * letterSpacingRatio;
  }

  static TextStyle applyToStyle(TextStyle style, {double? lineHeight}) {
    final fontSize = style.fontSize;
    return style.copyWith(
      height: lineHeight,
      letterSpacing: fontSize == null
          ? style.letterSpacing
          : letterSpacingFor(fontSize),
    );
  }

  static TextStyle withFontSize(
    TextStyle style,
    double fontSize, {
    double? lineHeight,
  }) {
    return applyToStyle(
      style.copyWith(fontSize: fontSize),
      lineHeight: lineHeight,
    );
  }

  static Typography applyToTypography(Typography typography) {
    return typography.copyWith(
      englishLike: applyToTextTheme(typography.englishLike),
      dense: applyToTextTheme(typography.dense),
      tall: applyToTextTheme(typography.tall),
    );
  }

  static TextTheme applyToTextTheme(TextTheme theme) {
    return theme.copyWith(
      displayLarge: _apply(theme.displayLarge),
      displayMedium: _apply(theme.displayMedium),
      displaySmall: _apply(theme.displaySmall),
      headlineLarge: _apply(theme.headlineLarge),
      headlineMedium: _apply(theme.headlineMedium),
      headlineSmall: _apply(theme.headlineSmall),
      titleLarge: _apply(theme.titleLarge),
      titleMedium: _apply(theme.titleMedium),
      titleSmall: _apply(theme.titleSmall),
      bodyLarge: _apply(theme.bodyLarge, lineHeight: bodyLineHeight),
      bodyMedium: _apply(theme.bodyMedium, lineHeight: bodyLineHeight),
      bodySmall: _apply(theme.bodySmall, lineHeight: bodyLineHeight),
      labelLarge: _apply(theme.labelLarge),
      labelMedium: _apply(theme.labelMedium),
      labelSmall: _apply(theme.labelSmall),
    );
  }

  static TextStyle? _apply(TextStyle? style, {double? lineHeight}) {
    return style == null ? null : applyToStyle(style, lineHeight: lineHeight);
  }
}
