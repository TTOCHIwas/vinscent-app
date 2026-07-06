enum StoryLoopReadFailureReason {
  configMissing,
  authRequired,
  relationshipDateRequired,
  requestTimeout,
  unknown,
}

class StoryLoopReadRepositoryException implements Exception {
  const StoryLoopReadRepositoryException(this.reason, [this.message]);

  final StoryLoopReadFailureReason reason;
  final String? message;

  @override
  String toString() {
    final detail = message;
    if (detail == null || detail.isEmpty) {
      return 'StoryLoopReadRepositoryException($reason)';
    }

    return 'StoryLoopReadRepositoryException($reason, $detail)';
  }
}
