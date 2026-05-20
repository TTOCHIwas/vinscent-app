import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/config/app_config.dart';
import 'social_auth_failure.dart';

final kakaoAuthClientProvider = Provider<KakaoAuthClient>(
  (ref) => const KakaoAuthClient(),
);

class KakaoAuthClient {
  const KakaoAuthClient();

  Future<KakaoLoginTokens> signIn() async {
    if (!AppConfig.isKakaoConfigured) {
      throw const SocialAuthFailure(
        SocialAuthFailureReason.notConfigured,
        message: 'Kakao native app key is missing.',
      );
    }

    try {
      final token = await _requestToken();
      final idToken = token.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const SocialAuthFailure(
          SocialAuthFailureReason.missingIdToken,
          message: 'Kakao OpenID Connect must be enabled with openid scope.',
        );
      }

      return KakaoLoginTokens(idToken: idToken, accessToken: token.accessToken);
    } on SocialAuthFailure {
      rethrow;
    } catch (error, stackTrace) {
      if (_isCancelled(error)) {
        throw SocialAuthFailure(
          SocialAuthFailureReason.cancelled,
          cause: error,
          stackTrace: stackTrace,
        );
      }

      throw SocialAuthFailure(
        SocialAuthFailureReason.providerFailed,
        message: 'Kakao login failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<OAuthToken> _requestToken() async {
    if (!await isKakaoTalkInstalled()) {
      return UserApi.instance.loginWithKakaoAccount();
    }

    try {
      return await UserApi.instance.loginWithKakaoTalk();
    } catch (error) {
      if (_isCancelled(error)) {
        rethrow;
      }

      return UserApi.instance.loginWithKakaoAccount();
    }
  }

  bool _isCancelled(Object error) {
    return switch (error) {
      PlatformException(:final code) => code == 'CANCELED',
      KakaoAuthException(:final error) => error == AuthErrorCause.accessDenied,
      KakaoApiException(:final code) => code == ApiErrorCause.accessDenied,
      KakaoClientException(:final reason) =>
        reason == ClientErrorCause.cancelled,
      _ => false,
    };
  }
}

class KakaoLoginTokens {
  const KakaoLoginTokens({required this.idToken, required this.accessToken});

  final String idToken;
  final String accessToken;
}
