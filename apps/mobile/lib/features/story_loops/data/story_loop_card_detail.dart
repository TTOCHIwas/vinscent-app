class StoryLoopCardDetail {
  const StoryLoopCardDetail({
    required this.id,
    required this.authorUserId,
    required this.previewPath,
    required this.sceneDataPath,
    required this.hasPhoto,
    required this.hasDrawing,
    required this.hasText,
    required this.submittedAt,
    required this.revision,
  });

  final String id;
  final String authorUserId;
  final String previewPath;
  final String sceneDataPath;
  final bool hasPhoto;
  final bool hasDrawing;
  final bool hasText;
  final DateTime submittedAt;
  final int revision;
}
