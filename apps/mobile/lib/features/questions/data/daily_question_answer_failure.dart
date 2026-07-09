enum DailyQuestionAnswerFailureReason {
  authRequired,
  activeCoupleRequired,
  relationshipDateRequired,
  questionPoolEmpty,
  questionAssignmentFailed,
  questionNotReady,
  answerRequired,
  answerTooLong,
  configMissing,
  requestTimeout,
  unknown,
}

class DailyQuestionAnswerRepositoryException implements Exception {
  const DailyQuestionAnswerRepositoryException(this.reason, [this.message]);

  final DailyQuestionAnswerFailureReason reason;
  final String? message;

  @override
  String toString() {
    return message ?? reason.name;
  }
}
