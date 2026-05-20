enum SocialAuthProvider { kakao, apple }

enum SocialAuthFailureReason {
  cancelled,
  notConfigured,
  missingIdToken,
  providerFailed,
  supabaseSessionFailed,
  unsupportedPlatform,
}

class SocialAuthFailure implements Exception {
  const SocialAuthFailure(
    this.reason, {
    this.message,
    this.cause,
    this.stackTrace,
  });

  final SocialAuthFailureReason reason;
  final String? message;
  final Object? cause;
  final StackTrace? stackTrace;

  bool get isCancelled => reason == SocialAuthFailureReason.cancelled;

  @override
  String toString() {
    final detail = message == null ? '' : ': $message';
    return 'SocialAuthFailure($reason$detail)';
  }
}
