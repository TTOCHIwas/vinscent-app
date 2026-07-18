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
  relationshipDateRequired,
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
