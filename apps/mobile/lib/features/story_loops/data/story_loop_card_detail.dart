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
    this.previewUrl,
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
  final String? previewUrl;

  StoryLoopCardDetail copyWith({String? previewUrl}) {
    return StoryLoopCardDetail(
      id: id,
      authorUserId: authorUserId,
      previewPath: previewPath,
      sceneDataPath: sceneDataPath,
      hasPhoto: hasPhoto,
      hasDrawing: hasDrawing,
      hasText: hasText,
      submittedAt: submittedAt,
      revision: revision,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }
}
