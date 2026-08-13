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
}
