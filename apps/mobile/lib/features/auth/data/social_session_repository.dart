import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'kakao_auth_client.dart';
import 'social_auth_failure.dart';

final socialSessionRepositoryProvider = Provider<SocialSessionRepository>(
  (ref) => const SupabaseSocialSessionRepository(),
);

abstract interface class SocialSessionRepository {
  Future<void> signInWithKakao(KakaoLoginTokens tokens);
}

class SupabaseSocialSessionRepository implements SocialSessionRepository {
  const SupabaseSocialSessionRepository();

  @override
  Future<void> signInWithKakao(KakaoLoginTokens tokens) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const SocialAuthFailure(
        SocialAuthFailureReason.notConfigured,
        message: 'Supabase config is missing.',
      );
    }

    try {
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      );

      if (response.session == null) {
        throw const SocialAuthFailure(
          SocialAuthFailureReason.supabaseSessionFailed,
          message: 'Supabase session was not created.',
        );
      }
    } on SocialAuthFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw SocialAuthFailure(
        SocialAuthFailureReason.supabaseSessionFailed,
        message: 'Kakao token exchange failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
