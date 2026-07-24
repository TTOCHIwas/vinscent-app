import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_text_styles.dart';
import 'package:vinscent/core/theme/app_theme.dart';
import 'package:vinscent/core/theme/app_typography.dart';

void main() {
  test('converts the global tracking percentage for each font size', () {
    expect(AppTypography.letterSpacingFor(16), closeTo(-0.4, 0.0001));
    expect(AppTypography.letterSpacingFor(24), closeTo(-0.6, 0.0001));

    final resized = AppTypography.withFontSize(AppTextStyles.shellTitle, 20);
    expect(resized.height, AppTextStyles.shellTitle.height);
    expect(resized.letterSpacing, closeTo(-0.5, 0.0001));
  });

  test('preserves semantic heights while customizing typography geometry', () {
    final base = Typography.material2021(
      platform: TargetPlatform.android,
    ).dense;
    final customized = AppTypography.applyToTextTheme(base);

    expect(customized.displayLarge?.height, base.displayLarge?.height);
    expect(customized.titleMedium?.height, base.titleMedium?.height);
    expect(customized.labelSmall?.height, base.labelSmall?.height);
    expect(customized.bodyLarge?.height, AppTypography.bodyLineHeight);
    expect(customized.bodyMedium?.height, AppTypography.bodyLineHeight);
    expect(customized.bodySmall?.height, AppTypography.bodyLineHeight);
    expect(customized.bodyMedium?.textBaseline, TextBaseline.ideographic);

    for (final style in _textThemeStyles(customized)) {
      _expectTracking(style);
    }
  });

  testWidgets('uses localized Korean typography in light and dark themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      late TextTheme textTheme;
      late TextTheme primaryTextTheme;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('ko')],
          theme: theme,
          home: Builder(
            builder: (context) {
              final localizedTheme = Theme.of(context);
              textTheme = localizedTheme.textTheme;
              primaryTextTheme = localizedTheme.primaryTextTheme;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      for (final localizedTextTheme in [textTheme, primaryTextTheme]) {
        expect(
          localizedTextTheme.bodyMedium?.textBaseline,
          TextBaseline.ideographic,
        );
        expect(
          localizedTextTheme.bodyMedium?.height,
          AppTypography.bodyLineHeight,
        );
        expect(
          localizedTextTheme.labelSmall?.height,
          Typography.dense2021.labelSmall?.height,
        );
        for (final style in _textThemeStyles(localizedTextTheme)) {
          _expectTracking(style);
        }
      }
    }
  });

  test('keeps project text styles aligned with their layout roles', () {
    final expectedHeights = <(TextStyle, double)>[
      (AppTextStyles.shellTitle, 22 / 18),
      (AppTextStyles.shellNavigation, 20 / 16),
      (AppTextStyles.homeBody, AppTypography.bodyLineHeight),
      (AppTextStyles.homeBodyMedium, AppTypography.bodyLineHeight),
      (AppTextStyles.homeQuestionBubble, AppTypography.bodyLineHeight),
      (AppTextStyles.shellDayCount, 1.2),
      (AppTextStyles.homeCharacterLabel, AppTypography.bodyLineHeight),
      (AppTextStyles.onboardingTitle, 34 / 24),
      (AppTextStyles.onboardingInput, 30 / 22),
      (AppTextStyles.onboardingHint, 20 / 14),
      (AppTextStyles.onboardingButton, 24 / 16),
      (AppTextStyles.socialButton, 24 / 16),
      (AppTextStyles.logoLabel, 1.2),
      (AppTextStyles.sectionTitle, 24 / 18),
      (AppTextStyles.pageTitle, 28 / 20),
      (AppTextStyles.compactError, 18 / 13),
      (AppTextStyles.drawingToolLabel, 18 / 13),
      (AppTextStyles.storyEditorTitle, 20 / 16),
    ];

    for (final (style, expectedHeight) in expectedHeights) {
      expect(style.height, closeTo(expectedHeight, 0.0001));
      _expectTracking(style);
    }
  });
}

Iterable<TextStyle> _textThemeStyles(TextTheme theme) sync* {
  final styles = [
    theme.displayLarge,
    theme.displayMedium,
    theme.displaySmall,
    theme.headlineLarge,
    theme.headlineMedium,
    theme.headlineSmall,
    theme.titleLarge,
    theme.titleMedium,
    theme.titleSmall,
    theme.bodyLarge,
    theme.bodyMedium,
    theme.bodySmall,
    theme.labelLarge,
    theme.labelMedium,
    theme.labelSmall,
  ];
  yield* styles.nonNulls;
}

void _expectTracking(TextStyle style) {
  final fontSize = style.fontSize;
  if (fontSize == null) {
    return;
  }
  expect(
    style.letterSpacing,
    closeTo(AppTypography.letterSpacingFor(fontSize), 0.0001),
  );
}
