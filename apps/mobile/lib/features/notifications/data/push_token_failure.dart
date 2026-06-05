enum PushTokenFailureReason {
  configMissing,
  unsupportedPlatform,
  requestTimeout,
  authRequired,
  invalidPushToken,
  invalidPushPlatform,
  unknown,
}

class PushTokenRepositoryException implements Exception {
  const PushTokenRepositoryException(this.reason, [this.message]);

  final PushTokenFailureReason reason;
  final String? message;

  @override
  String toString() {
    if (message == null) {
      return 'PushTokenRepositoryException($reason)';
    }

    return 'PushTokenRepositoryException($reason, $message)';
  }
}
