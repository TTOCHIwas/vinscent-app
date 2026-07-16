import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/app/app.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('redirects unauthenticated users to login screen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: VinscentApp()));
    await tester.pumpAndSettle();

    expect(find.text('카카오 로그인'), findsOneWidget);
    expect(find.text('Apple로 로그인'), findsOneWidget);
  });

  testWidgets('keeps the app in light mode when the system is dark', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const ProviderScope(child: VinscentApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(LoginScreen));
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppColors.actionPrimary);
    expect(theme.colorScheme.surface, AppColors.background);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });
}
