import 'package:flutter/material.dart';

import '../../data/story_card_stack_preview.dart';
import '../../data/story_loop_card_detail.dart';
import '../../data/story_loop_card_preview.dart';
import 'story_card_stack_overlay.dart';

Future<void> showStoryCardDetailOverlay({
  required BuildContext context,
  required DateTime date,
  required StoryLoopCardDetail card,
  required bool isMine,
}) {
  return showStoryCardStackOverlay(
    context: context,
    date: date,
    stack: StoryCardStackPreview(
      authorUserId: card.authorUserId,
      latestCard: StoryLoopCardPreview(
        id: card.id,
        authorUserId: card.authorUserId,
        previewPath: card.previewPath,
        submittedAt: card.submittedAt,
        cardType: card.cardType,
        previewUrl: card.previewUrl,
      ),
      latestCardIsFeatured: false,
      cardCount: 1,
      isMine: isMine,
    ),
    initialCardId: card.id,
  );
}
