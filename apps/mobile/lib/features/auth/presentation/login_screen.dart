import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/social_login_controller.dart';
import '../application/social_login_state.dart';
import '../data/social_auth_failure.dart';
import 'widgets/apple_login_button.dart';
import 'widgets/kakao_login_button.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loginState = ref.watch(socialLoginControllerProvider);

    ref.listen<SocialLoginState>(socialLoginControllerProvider, (
      previous,
      next,
    ) {
      final failure = next.failure;
      if (failure == null || failure.isCancelled) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_messageFor(failure))));
    });

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
                      onPressed: loginState.isSigningIn
                          ? null
                          : () => ref
                                .read(socialLoginControllerProvider.notifier)
                                .signInWithKakao(),
                    ),
                    AppleLoginButton(
                      onPressed: loginState.isSigningIn
                          ? null
                          : () => ref
                                .read(socialLoginControllerProvider.notifier)
                                .signInWithApple(),
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

  String _messageFor(SocialAuthFailure failure) {
    return switch (failure.reason) {
      SocialAuthFailureReason.notConfigured => '로그인 설정이 아직 완료되지 않았습니다.',
      SocialAuthFailureReason.missingIdToken => '로그인 제공자 설정을 확인해주세요.',
      SocialAuthFailureReason.providerFailed => '로그인에 실패했습니다.',
      SocialAuthFailureReason.supabaseSessionFailed => '로그인 세션 생성에 실패했습니다.',
      SocialAuthFailureReason.unsupportedPlatform => '현재 기기에서는 지원하지 않는 로그인입니다.',
      SocialAuthFailureReason.cancelled => '',
    };
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
