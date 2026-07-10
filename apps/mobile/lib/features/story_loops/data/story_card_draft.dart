import 'dart:typed_data';

import 'story_card_scene.dart';

class StoryCardDraft {
  const StoryCardDraft({
    required this.scene,
    this.backgroundImageBytes,
    this.existingRevision,
  });

  final StoryCardScene scene;
  final Uint8List? backgroundImageBytes;
  final int? existingRevision;

  bool get hasPhoto => backgroundImageBytes != null;

  bool get hasContent => hasPhoto || scene.hasDrawing || scene.hasText;

  StoryCardDraft copyWith({
    StoryCardScene? scene,
    Uint8List? backgroundImageBytes,
    bool clearBackgroundImage = false,
    int? existingRevision,
  }) {
    return StoryCardDraft(
      scene: scene ?? this.scene,
      backgroundImageBytes: clearBackgroundImage
          ? null
          : backgroundImageBytes ?? this.backgroundImageBytes,
      existingRevision: existingRevision ?? this.existingRevision,
    );
  }
}
