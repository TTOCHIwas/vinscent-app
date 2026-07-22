import 'dart:typed_data';

import 'story_card_scene.dart';

class StoryCardDownloadSource {
  const StoryCardDownloadSource({
    required this.scene,
    required this.backgroundImageBytes,
  });

  final StoryCardScene scene;
  final Uint8List? backgroundImageBytes;
}
