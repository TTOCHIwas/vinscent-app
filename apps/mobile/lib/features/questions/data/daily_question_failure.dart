enum DailyQuestionFailureReason {
  authRequired,
  activeCoupleRequired,
  relationshipDateRequired,
  questionPoolEmpty,
  configMissing,
  requestTimeout,
  unknown,
}

class DailyQuestionRepositoryException implements Exception {
  const DailyQuestionRepositoryException(this.reason, [this.message]);

  final DailyQuestionFailureReason reason;
  final String? message;

  @override
  String toString() {
    return message ?? reason.name;
  }
}
