import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'apple_auth_client.dart';
import 'kakao_auth_client.dart';
import 'social_auth_failure.dart';

final socialSessionRepositoryProvider = Provider<SocialSessionRepository>(
  (ref) => const SupabaseSocialSessionRepository(),
);

abstract interface class SocialSessionRepository {
  Future<void> signInWithKakao(KakaoLoginTokens tokens);

  Future<void> signInWithApple(AppleLoginTokens tokens);
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

  @override
  Future<void> signInWithApple(AppleLoginTokens tokens) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const SocialAuthFailure(
        SocialAuthFailureReason.notConfigured,
        message: 'Supabase config is missing.',
      );
    }

    try {
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: tokens.idToken,
        nonce: tokens.rawNonce,
      );

      if (response.session == null) {
        throw const SocialAuthFailure(
          SocialAuthFailureReason.supabaseSessionFailed,
          message: 'Supabase session was not created.',
        );
      }

      await _updateAppleNameMetadata(tokens);
    } on SocialAuthFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw SocialAuthFailure(
        SocialAuthFailureReason.supabaseSessionFailed,
        message: 'Apple token exchange failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _updateAppleNameMetadata(AppleLoginTokens tokens) async {
    final fullName = tokens.fullName;
    final givenName = tokens.givenName?.trim();
    final familyName = tokens.familyName?.trim();
    final data = <String, String>{};

    if (fullName != null) {
      data['full_name'] = fullName;
    }
    if (givenName != null && givenName.isNotEmpty) {
      data['given_name'] = givenName;
    }
    if (familyName != null && familyName.isNotEmpty) {
      data['family_name'] = familyName;
    }

    if (data.isEmpty) {
      return;
    }

    await Supabase.instance.client.auth.updateUser(UserAttributes(data: data));
  }
}
