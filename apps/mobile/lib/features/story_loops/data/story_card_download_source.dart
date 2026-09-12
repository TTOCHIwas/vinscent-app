import 'dart:typed_data';

import 'story_card_scene.dart';

class StoryCardDownloadSource {
  const StoryCardDownloadSource({
    required this.scene,
    required this.backgroundImageBytes,
    this.compositeImageBytes,
  });

  final StoryCardScene scene;
  final Uint8List? backgroundImageBytes;
  final Uint8List? compositeImageBytes;
}
