import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../auth_debug_log.dart';
import 'apple_auth_client.dart';
import 'kakao_auth_client.dart';
import 'social_auth_failure.dart';

final socialSessionRepositoryProvider = Provider<SocialSessionRepository>(
  (ref) => const SupabaseSocialSessionRepository(),
);

abstract interface class SocialSessionRepository {
  bool get canCreateSession;

  Future<void> signInWithKakao(KakaoLoginTokens tokens);

  Future<void> signInWithApple(AppleLoginTokens tokens);
}

class SupabaseSocialSessionRepository implements SocialSessionRepository {
  const SupabaseSocialSessionRepository();

  @override
  bool get canCreateSession => AppConfig.isSupabaseConfigured;

  @override
  Future<void> signInWithKakao(KakaoLoginTokens tokens) async {
    if (!canCreateSession) {
      debugAuthLog('supabase kakao exchange aborted: config missing');
      throw const SocialAuthFailure(
        SocialAuthFailureReason.notConfigured,
        message: 'Supabase config is missing.',
      );
    }

    try {
      debugAuthLog(
        'supabase kakao exchange requested '
        'idToken=${summarizeAuthValue(tokens.idToken)} '
        'accessToken=${summarizeAuthValue(tokens.accessToken)}',
      );
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      );

      debugAuthLog(
        'supabase kakao exchange completed '
        'sessionUserId=${summarizeAuthValue(response.session?.user.id)}',
      );

      if (response.session == null) {
        debugAuthLog('supabase kakao exchange failed: session missing');
        throw const SocialAuthFailure(
          SocialAuthFailureReason.supabaseSessionFailed,
          message: 'Supabase session was not created.',
        );
      }
    } on SocialAuthFailure catch (failure) {
      debugAuthLog(
        'supabase kakao exchange failed reason=${failure.reason} '
        'message=${failure.message ?? '-'} cause=${failure.cause.runtimeType}',
      );
      rethrow;
    } catch (error, stackTrace) {
      debugAuthLog(
        'supabase kakao exchange threw error=${error.runtimeType} message=$error',
      );
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
    if (!canCreateSession) {
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
