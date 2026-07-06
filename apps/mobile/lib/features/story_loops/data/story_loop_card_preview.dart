class StoryLoopCardPreview {
  const StoryLoopCardPreview({
    required this.id,
    required this.authorUserId,
    required this.previewPath,
    required this.submittedAt,
  });

  final String id;
  final String authorUserId;
  final String previewPath;
  final DateTime submittedAt;
}
