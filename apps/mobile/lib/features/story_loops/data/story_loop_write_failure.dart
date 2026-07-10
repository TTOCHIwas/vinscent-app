enum StoryLoopWriteFailureReason {
  configMissing,
  authRequired,
  activeCoupleRequired,
  relationshipDateRequired,
  storyNotReady,
  contentRequired,
  invalidTextContent,
  cardLocked,
  revisionRequired,
  revisionConflict,
  cardNotFound,
  questionPoolEmpty,
  requestTimeout,
  storage,
  unknown,
}

class StoryLoopWriteRepositoryException implements Exception {
  const StoryLoopWriteRepositoryException(this.reason, [this.message]);

  final StoryLoopWriteFailureReason reason;
  final String? message;
}
