class StoryLoopCardSaveResult {
  const StoryLoopCardSaveResult({
    required this.storyLoopId,
    required this.storyLoopStatus,
    required this.cardId,
    required this.cardRevision,
  });

  final String storyLoopId;
  final String storyLoopStatus;
  final String cardId;
  final int cardRevision;
}
