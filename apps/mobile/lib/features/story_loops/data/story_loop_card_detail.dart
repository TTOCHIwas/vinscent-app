import 'story_card_type.dart';

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
    this.cardType = StoryCardType.polaroid,
    this.layoutVersion = storyCardLegacyLayoutVersion,
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
  final StoryCardType cardType;
  final int layoutVersion;
  final String? previewUrl;

  double get canvasAspectRatio => cardType.canvasAspectRatioFor(layoutVersion);

  StoryLoopCardDetail copyWith({
    StoryCardType? cardType,
    int? layoutVersion,
    String? previewUrl,
  }) {
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
      cardType: cardType ?? this.cardType,
      layoutVersion: layoutVersion ?? this.layoutVersion,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }
}
