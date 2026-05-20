import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleLoginButton extends StatelessWidget {
  const AppleLoginButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SignInWithAppleButton(
        onPressed: onPressed,
        text: 'Apple로 로그인',
        height: 56,
        style: SignInWithAppleButtonStyle.black,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
