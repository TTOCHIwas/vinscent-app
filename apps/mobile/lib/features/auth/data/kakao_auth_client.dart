import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/config/app_config.dart';
import '../auth_debug_log.dart';
import 'social_auth_failure.dart';

final kakaoAuthClientProvider = Provider<KakaoAuthClient>(
  (ref) => const KakaoAuthClient(),
);

class KakaoAuthClient {
  const KakaoAuthClient();

  Future<KakaoLoginTokens> signIn() async {
    if (!AppConfig.isKakaoConfigured) {
      debugAuthLog('kakao sign-in aborted: native app key is missing');
      throw const SocialAuthFailure(
        SocialAuthFailureReason.notConfigured,
        message: 'Kakao native app key is missing.',
      );
    }

    try {
      debugAuthLog('kakao sign-in requested');
      final token = await _requestToken();
      final idToken = token.idToken;

      debugAuthLog(
        'kakao token received '
        'idToken=${summarizeAuthValue(idToken)} '
        'accessToken=${summarizeAuthValue(token.accessToken)}',
      );

      if (idToken == null || idToken.isEmpty) {
        debugAuthLog('kakao sign-in failed: idToken missing');
        throw const SocialAuthFailure(
          SocialAuthFailureReason.missingIdToken,
          message: 'Kakao OpenID Connect must be enabled with openid scope.',
        );
      }

      debugAuthLog('kakao sign-in succeeded');
      return KakaoLoginTokens(idToken: idToken, accessToken: token.accessToken);
    } on SocialAuthFailure catch (failure) {
      debugAuthLog(
        'kakao sign-in failed reason=${failure.reason} '
        'message=${failure.message ?? '-'} cause=${failure.cause.runtimeType}',
      );
      rethrow;
    } catch (error, stackTrace) {
      if (_isCancelled(error)) {
        debugAuthLog('kakao sign-in cancelled error=${error.runtimeType}');
        throw SocialAuthFailure(
          SocialAuthFailureReason.cancelled,
          cause: error,
          stackTrace: stackTrace,
        );
      }

      debugAuthLog(
        'kakao sign-in threw provider error=${error.runtimeType} message=$error',
      );
      throw SocialAuthFailure(
        SocialAuthFailureReason.providerFailed,
        message: 'Kakao login failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<OAuthToken> _requestToken() async {
    final isInstalled = await isKakaoTalkInstalled();
    debugAuthLog('kakao talk installed=$isInstalled');

    if (!isInstalled) {
      debugAuthLog('kakao account login requested');
      return UserApi.instance.loginWithKakaoAccount();
    }

    try {
      debugAuthLog('kakao talk login requested');
      return await UserApi.instance.loginWithKakaoTalk();
    } catch (error) {
      if (_isCancelled(error)) {
        debugAuthLog('kakao talk login cancelled');
        rethrow;
      }

      debugAuthLog(
        'kakao talk login failed, falling back to account login '
        'error=${error.runtimeType} message=$error',
      );
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
