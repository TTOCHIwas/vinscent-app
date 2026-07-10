import 'dart:typed_data';

import 'story_card_scene.dart';

class EditableStoryLoopCard {
  const EditableStoryLoopCard({
    required this.storyLoopId,
    required this.cardId,
    required this.revision,
    required this.scene,
    this.backgroundImageBytes,
  });

  final String storyLoopId;
  final String cardId;
  final int revision;
  final StoryCardScene scene;
  final Uint8List? backgroundImageBytes;
}

class StoryLoopCardSaveResult {
  const StoryLoopCardSaveResult({
    required this.storyLoopId,
    required this.storyLoopStatus,
    required this.cardId,
    required this.cardRevision,
    required this.questionGenerated,
    this.dailyQuestionId,
  });

  final String storyLoopId;
  final String storyLoopStatus;
  final String cardId;
  final int cardRevision;
  final bool questionGenerated;
  final String? dailyQuestionId;
}
