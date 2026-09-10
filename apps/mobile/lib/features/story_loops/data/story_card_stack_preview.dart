import 'story_loop_card_preview.dart';

class StoryCardStackPreview {
  const StoryCardStackPreview({
    required this.authorUserId,
    required this.latestCard,
    required this.latestCardIsFeatured,
    required this.cardCount,
    required this.isMine,
  });

  factory StoryCardStackPreview.fromJson(
    Map<String, dynamic> json, {
    String? previewUrl,
  }) {
    final previewPath = json['latest_card_preview_path'] as String;
    final authorUserId = json['author_user_id'] as String;
    return StoryCardStackPreview(
      authorUserId: authorUserId,
      latestCard: StoryLoopCardPreview(
        id: json['latest_card_id'] as String,
        authorUserId: authorUserId,
        previewPath: previewPath,
        submittedAt: DateTime.parse(json['latest_card_submitted_at'] as String),
        previewUrl: previewUrl,
      ),
      latestCardIsFeatured: json['latest_card_is_featured'] as bool? ?? false,
      cardCount: (json['card_count'] as num).toInt(),
      isMine: json['is_mine'] as bool? ?? false,
    );
  }

  final String authorUserId;
  final StoryLoopCardPreview latestCard;
  final bool latestCardIsFeatured;
  final int cardCount;
  final bool isMine;
}
