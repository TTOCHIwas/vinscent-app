class StoryLoopCardPreview {
  const StoryLoopCardPreview({
    required this.id,
    required this.authorUserId,
    required this.previewPath,
    required this.submittedAt,
    this.previewUrl,
  });

  final String id;
  final String authorUserId;
  final String previewPath;
  final DateTime submittedAt;
  final String? previewUrl;

  StoryLoopCardPreview copyWith({String? previewUrl}) {
    return StoryLoopCardPreview(
      id: id,
      authorUserId: authorUserId,
      previewPath: previewPath,
      submittedAt: submittedAt,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }
}
