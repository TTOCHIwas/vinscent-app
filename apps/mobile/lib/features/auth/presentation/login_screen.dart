import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'widgets/apple_login_button.dart';
import 'widgets/kakao_login_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 56, 32, 34),
          child: Column(
            children: [
              const Expanded(child: Center(child: _LogoMark())),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Column(
                  spacing: 8,
                  children: [
                    KakaoLoginButton(
                      onPressed: () => _showAuthPending(context, '카카오'),
                    ),
                    AppleLoginButton(
                      onPressed: () => _showAuthPending(context, 'Apple'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuthPending(BuildContext context, String provider) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$provider 로그인 연동 준비 중입니다.')));
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.logoBackground,
            borderRadius: BorderRadius.circular(0),
          ),
          child: const SizedBox(width: 80, height: 80),
        ),
        const SizedBox(height: 12),
        const SizedBox(
          width: 80,
          child: Text(
            '로고',
            textAlign: TextAlign.center,
            style: AppTextStyles.logoLabel,
          ),
        ),
      ],
    );
  }
}
