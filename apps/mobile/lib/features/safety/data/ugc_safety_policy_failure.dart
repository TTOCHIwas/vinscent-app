enum UgcSafetyPolicyFailureReason {
  configMissing,
  authRequired,
  versionOutdated,
  requestTimeout,
  invalidResponse,
  unknown,
}

class UgcSafetyPolicyException implements Exception {
  const UgcSafetyPolicyException(this.reason, [this.message]);

  final UgcSafetyPolicyFailureReason reason;
  final String? message;

  @override
  String toString() => message ?? reason.name;
}
