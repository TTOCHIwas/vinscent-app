import 'package:flutter/foundation.dart';

import '../data/story_card_film_look.dart';
import 'story_card_face_effect.dart';

@immutable
class StoryCardCameraSelection {
  const StoryCardCameraSelection({
    required this.imageBytes,
    required this.film,
    this.characterComposition,
  });

  final Uint8List imageBytes;
  final StoryCardFilmState film;
  final StoryCardCharacterComposition? characterComposition;
}
