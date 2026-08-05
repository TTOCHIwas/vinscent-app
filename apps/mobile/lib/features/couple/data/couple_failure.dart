enum CoupleFailureReason {
  authRequired,
  profileRequired,
  alreadyExists,
  archivedCoupleExists,
  archivedCoupleRequired,
  inviteNotFound,
  inviteNotPending,
  ownInvite,
  invalidCode,
  futureDate,
  activeCoupleRequired,
  initialSetupOwnerRequired,
  initialSetupCancelNotAvailable,
  relationshipDateRequired,
  relationshipDateConflict,
  codeGenerationFailed,
  configMissing,
  unknown,
}

class CoupleRepositoryException implements Exception {
  const CoupleRepositoryException(this.reason, [this.message]);

  final CoupleFailureReason reason;
  final String? message;

  @override
  String toString() {
    return message ?? reason.name;
  }
}
