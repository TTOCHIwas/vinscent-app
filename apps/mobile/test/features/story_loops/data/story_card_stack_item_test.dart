import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_stack_item.dart';

void main() {
  test('maps viewer permissions independently for every card', () {
    final item = StoryCardStackItem.fromJson({
      'position': 2,
      'card_id': 'card-2',
      'author_user_id': 'user-a',
      'preview_path': 'preview/card-2.png',
      'scene_data_path': 'scene/card-2.json',
      'has_photo': true,
      'has_drawing': false,
      'has_text': true,
      'submitted_at': '2026-09-09T03:04:05Z',
      'revision': 1,
      'is_featured': false,
      'can_delete': true,
      'can_feature': true,
      'is_read': true,
    }, previewUrl: 'https://example.test/card-2.png');

    expect(item.position, 2);
    expect(item.card.id, 'card-2');
    expect(item.card.previewUrl, 'https://example.test/card-2.png');
    expect(item.isFeatured, isFalse);
    expect(item.canDelete, isTrue);
    expect(item.canFeature, isTrue);
    expect(item.isRead, isTrue);
  });
}
