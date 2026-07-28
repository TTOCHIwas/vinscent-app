enum SafetyReportFailureReason {
  configMissing,
  authRequired,
  activeCoupleRequired,
  invalidTarget,
  targetNotAvailable,
  invalidReason,
  detailsTooLong,
  snapshotRequired,
  snapshotTooLong,
  requestTimeout,
  unknown,
}

class SafetyReportException implements Exception {
  const SafetyReportException(this.reason, [this.message]);

  final SafetyReportFailureReason reason;
  final String? message;

  @override
  String toString() => message ?? reason.name;
}
