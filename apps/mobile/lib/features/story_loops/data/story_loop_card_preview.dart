import 'story_card_type.dart';

class StoryLoopCardPreview {
  const StoryLoopCardPreview({
    required this.id,
    required this.authorUserId,
    required this.previewPath,
    required this.submittedAt,
    this.cardType = StoryCardType.polaroid,
    this.layoutVersion = storyCardLegacyLayoutVersion,
    this.previewUrl,
  });

  final String id;
  final String authorUserId;
  final String previewPath;
  final DateTime submittedAt;
  final StoryCardType cardType;
  final int layoutVersion;
  final String? previewUrl;

  double get canvasAspectRatio => cardType.canvasAspectRatioFor(layoutVersion);

  StoryLoopCardPreview copyWith({
    StoryCardType? cardType,
    int? layoutVersion,
    String? previewUrl,
  }) {
    return StoryLoopCardPreview(
      id: id,
      authorUserId: authorUserId,
      previewPath: previewPath,
      submittedAt: submittedAt,
      cardType: cardType ?? this.cardType,
      layoutVersion: layoutVersion ?? this.layoutVersion,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }
}
