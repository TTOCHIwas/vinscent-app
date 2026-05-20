import '../data/social_auth_failure.dart';

enum SocialLoginStatus { idle, signingIn }

class SocialLoginState {
  const SocialLoginState.idle({this.failure})
    : status = SocialLoginStatus.idle,
      provider = null;

  const SocialLoginState.signingIn(this.provider)
    : status = SocialLoginStatus.signingIn,
      failure = null;

  final SocialLoginStatus status;
  final SocialAuthProvider? provider;
  final SocialAuthFailure? failure;

  bool get isSigningIn => status == SocialLoginStatus.signingIn;

  bool isSigningInWith(SocialAuthProvider targetProvider) {
    return isSigningIn && provider == targetProvider;
  }
}
