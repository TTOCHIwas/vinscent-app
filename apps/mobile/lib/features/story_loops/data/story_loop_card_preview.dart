import 'story_card_type.dart';

class StoryLoopCardPreview {
  const StoryLoopCardPreview({
    required this.id,
    required this.authorUserId,
    required this.previewPath,
    required this.submittedAt,
    this.cardType = StoryCardType.polaroid,
    this.previewUrl,
  });

  final String id;
  final String authorUserId;
  final String previewPath;
  final DateTime submittedAt;
  final StoryCardType cardType;
  final String? previewUrl;

  StoryLoopCardPreview copyWith({StoryCardType? cardType, String? previewUrl}) {
    return StoryLoopCardPreview(
      id: id,
      authorUserId: authorUserId,
      previewPath: previewPath,
      submittedAt: submittedAt,
      cardType: cardType ?? this.cardType,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }
}
