enum CoupleCharacterFailureReason {
  configMissing,
  authRequired,
  activeCoupleRequired,
  initialSetupOwnerRequired,
  relationshipDateRequired,
  invalidPath,
  requestTimeout,
  storage,
  unknown,
}

class CoupleCharacterRepositoryException implements Exception {
  const CoupleCharacterRepositoryException(this.reason, [this.message]);

  final CoupleCharacterFailureReason reason;
  final String? message;
}
