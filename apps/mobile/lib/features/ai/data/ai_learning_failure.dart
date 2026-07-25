enum AiLearningFailureReason {
  authRequired,
  activeCoupleRequired,
  consentRequired,
  memoryNotFound,
  memoryConfirmationForbidden,
  memoryReviewNotReady,
  memoryAlreadyReviewed,
  personalizationNotReady,
  curriculumUnavailable,
  focusedQuestionsLocked,
  answerRequired,
  answerTooLong,
  questionRequired,
  questionTooLong,
  dailyQuestionLimitReached,
  sensitiveQuestionNotAvailable,
  invalidUserQuestion,
  invalidFollowUpDecision,
  followUpNotFound,
  followUpAlreadyDecided,
  followUpNotAvailable,
  followUpDuplicate,
  followUpQueueFull,
  questionNotReady,
  invalidQuestion,
  configMissing,
  requestTimeout,
  invalidResponse,
  unknown,
}

class AiLearningRepositoryException implements Exception {
  const AiLearningRepositoryException(this.reason, [this.message]);

  final AiLearningFailureReason reason;
  final String? message;

  @override
  String toString() => message ?? reason.name;
}
