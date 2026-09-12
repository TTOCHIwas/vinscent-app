import 'story_loop_card_detail.dart';
import 'story_card_type.dart';

class StoryCardStackItem {
  const StoryCardStackItem({
    required this.position,
    required this.card,
    required this.isFeatured,
    required this.canDelete,
    required this.canFeature,
    required this.isRead,
  });

  factory StoryCardStackItem.fromJson(
    Map<String, dynamic> json, {
    String? previewUrl,
  }) {
    final previewPath = json['preview_path'] as String;
    return StoryCardStackItem(
      position: (json['position'] as num).toInt(),
      card: StoryLoopCardDetail(
        id: json['card_id'] as String,
        authorUserId: json['author_user_id'] as String,
        previewPath: previewPath,
        sceneDataPath: json['scene_data_path'] as String,
        hasPhoto: json['has_photo'] as bool? ?? false,
        hasDrawing: json['has_drawing'] as bool? ?? false,
        hasText: json['has_text'] as bool? ?? false,
        submittedAt: DateTime.parse(json['submitted_at'] as String),
        revision: (json['revision'] as num).toInt(),
        cardType: StoryCardType.fromStorageValue(json['card_type'] as String?),
        previewUrl: previewUrl,
      ),
      isFeatured: json['is_featured'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
      canFeature: json['can_feature'] as bool? ?? false,
      isRead: json['is_read'] as bool? ?? true,
    );
  }

  final int position;
  final StoryLoopCardDetail card;
  final bool isFeatured;
  final bool canDelete;
  final bool canFeature;
  final bool isRead;
}
