enum DailyQuestionHistoryFailureReason {
  configMissing,
  authRequired,
  activeCoupleRequired,
  relationshipDateRequired,
  unknown,
}

class DailyQuestionHistoryRepositoryException implements Exception {
  const DailyQuestionHistoryRepositoryException(this.reason, [this.message]);

  final DailyQuestionHistoryFailureReason reason;
  final String? message;
}
