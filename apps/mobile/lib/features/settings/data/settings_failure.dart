enum SettingsFailureReason {
  authRequired,
  invalidDeliveryTime,
  configMissing,
  unknown,
}

class SettingsRepositoryException implements Exception {
  const SettingsRepositoryException(this.reason, [this.message]);

  final SettingsFailureReason reason;
  final String? message;

  @override
  String toString() {
    return message ?? reason.name;
  }
}
