import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_stack_preview.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';

void main() {
  test('maps a latest-card row without expanding the whole stack', () {
    final stack = StoryCardStackPreview.fromJson({
      'author_user_id': 'user-a',
      'latest_card_id': 'card-3',
      'latest_card_preview_path': 'preview/card-3.png',
      'latest_card_type': 'four_cut_strip',
      'latest_layout_version': 2,
      'latest_card_submitted_at': '2026-09-09T03:04:05Z',
      'latest_card_is_featured': true,
      'card_count': 3,
      'is_mine': true,
    }, previewUrl: 'https://example.test/card-3.png');

    expect(stack.authorUserId, 'user-a');
    expect(stack.latestCard.id, 'card-3');
    expect(stack.latestCard.previewUrl, 'https://example.test/card-3.png');
    expect(stack.latestCard.cardType, StoryCardType.fourCutStrip);
    expect(stack.latestCard.layoutVersion, storyCardCurrentLayoutVersion);
    expect(stack.latestCard.canvasAspectRatio, 8 / 21);
    expect(stack.cardCount, 3);
    expect(stack.isMine, isTrue);
    expect(stack.latestCardIsFeatured, isTrue);
  });

  test('missing layout metadata keeps legacy saved-card geometry', () {
    final stack = StoryCardStackPreview.fromJson({
      'author_user_id': 'user-a',
      'latest_card_id': 'card-1',
      'latest_card_preview_path': 'preview/card-1.png',
      'latest_card_type': 'four_cut_grid',
      'latest_card_submitted_at': '2026-09-09T03:04:05Z',
      'card_count': 1,
    });

    expect(stack.latestCard.layoutVersion, storyCardLegacyLayoutVersion);
    expect(stack.latestCard.canvasAspectRatio, 4 / 5);
  });
}
