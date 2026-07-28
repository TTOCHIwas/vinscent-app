enum UserBlockFailureReason {
  configMissing,
  authRequired,
  activeCoupleRequired,
  coupleAlreadyExists,
  userBlocked,
  archiveNotAvailable,
  invalidResponse,
  requestTimeout,
  unknown,
}

class UserBlockException implements Exception {
  const UserBlockException(this.reason, [this.message]);

  final UserBlockFailureReason reason;
  final String? message;

  @override
  String toString() => message ?? reason.name;
}
