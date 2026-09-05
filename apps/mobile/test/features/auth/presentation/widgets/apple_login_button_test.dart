import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:vinscent/features/auth/presentation/widgets/apple_login_button.dart';

void main() {
  testWidgets('uses the Apple-provided sign-in button implementation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppleLoginButton(onPressed: () {})),
      ),
    );

    expect(find.byType(SignInWithAppleButton), findsOneWidget);
    expect(find.text('Apple로 로그인'), findsOneWidget);
  });

  testWidgets('keeps accessibility text inside a compact iPhone button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(3),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 326,
              child: AppleLoginButton(onPressed: () {}),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final buttonRect = tester.getRect(find.byType(SignInWithAppleButton));
    final labelRect = tester.getRect(find.text('Apple로 로그인'));
    expect(buttonRect.contains(labelRect.topLeft), isTrue);
    expect(buttonRect.contains(labelRect.bottomRight), isTrue);
  });
}
