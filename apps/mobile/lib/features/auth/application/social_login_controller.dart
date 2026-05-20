import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/apple_auth_client.dart';
import '../data/kakao_auth_client.dart';
import '../data/social_auth_failure.dart';
import '../data/social_session_repository.dart';
import 'social_login_state.dart';

final socialLoginControllerProvider =
    NotifierProvider<SocialLoginController, SocialLoginState>(
      SocialLoginController.new,
    );

class SocialLoginController extends Notifier<SocialLoginState> {
  @override
  SocialLoginState build() {
    return const SocialLoginState.idle();
  }

  Future<void> signInWithKakao() async {
    await _signIn(SocialAuthProvider.kakao, () async {
      final tokens = await ref.read(kakaoAuthClientProvider).signIn();
      await ref.read(socialSessionRepositoryProvider).signInWithKakao(tokens);
    });
  }

  Future<void> signInWithApple() async {
    await _signIn(SocialAuthProvider.apple, () async {
      final tokens = await ref.read(appleAuthClientProvider).signIn();
      await ref.read(socialSessionRepositoryProvider).signInWithApple(tokens);
    });
  }

  Future<void> _signIn(
    SocialAuthProvider provider,
    Future<void> Function() action,
  ) async {
    if (state.isSigningIn) {
      return;
    }

    state = SocialLoginState.signingIn(provider);

    try {
      await action();
      state = const SocialLoginState.idle();
    } on SocialAuthFailure catch (failure) {
      state = SocialLoginState.idle(failure: failure);
    } catch (error, stackTrace) {
      state = SocialLoginState.idle(
        failure: SocialAuthFailure(
          SocialAuthFailureReason.providerFailed,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
