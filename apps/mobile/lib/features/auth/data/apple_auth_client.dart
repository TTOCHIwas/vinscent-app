import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'social_auth_failure.dart';

final appleAuthClientProvider = Provider<AppleAuthClient>(
  (ref) => const AppleAuthClient(),
);

class AppleAuthClient {
  const AppleAuthClient();

  Future<AppleLoginTokens> signIn() async {
    if (!_supportsNativeAppleSignIn) {
      throw const SocialAuthFailure(
        SocialAuthFailureReason.unsupportedPlatform,
        message: 'Native Apple sign-in is only enabled on Apple platforms.',
      );
    }

    try {
      if (!await SignInWithApple.isAvailable()) {
        throw const SocialAuthFailure(
          SocialAuthFailureReason.unsupportedPlatform,
          message: 'Sign in with Apple is not available on this device.',
        );
      }

      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;

      if (idToken == null || idToken.isEmpty) {
        throw const SocialAuthFailure(
          SocialAuthFailureReason.missingIdToken,
          message: 'Apple identity token is missing.',
        );
      }

      return AppleLoginTokens(
        idToken: idToken,
        rawNonce: rawNonce,
        email: credential.email,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
    } on SocialAuthFailure {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (error, stackTrace) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw SocialAuthFailure(
          SocialAuthFailureReason.cancelled,
          cause: error,
          stackTrace: stackTrace,
        );
      }

      throw SocialAuthFailure(
        SocialAuthFailureReason.providerFailed,
        message: 'Apple authorization failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    } on SignInWithAppleNotSupportedException catch (error, stackTrace) {
      throw SocialAuthFailure(
        SocialAuthFailureReason.unsupportedPlatform,
        message: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw SocialAuthFailure(
        SocialAuthFailureReason.providerFailed,
        message: 'Apple login failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool get _supportsNativeAppleSignIn {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();

    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}

class AppleLoginTokens {
  const AppleLoginTokens({
    required this.idToken,
    required this.rawNonce,
    this.email,
    this.givenName,
    this.familyName,
  });

  final String idToken;
  final String rawNonce;
  final String? email;
  final String? givenName;
  final String? familyName;

  String? get fullName {
    final parts = [
      givenName?.trim(),
      familyName?.trim(),
    ].where((part) => part != null && part.isNotEmpty);
    final value = parts.join(' ');

    return value.isEmpty ? null : value;
  }
}
