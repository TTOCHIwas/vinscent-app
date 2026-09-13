import 'package:flutter/foundation.dart';

import '../data/story_card_film_look.dart';
import '../data/story_card_type.dart';
import 'story_card_face_effect.dart';

@immutable
class StoryCardCameraSelection {
  const StoryCardCameraSelection({
    required this.imageBytes,
    required this.film,
    required this.cardType,
    this.characterComposition,
  });

  final Uint8List imageBytes;
  final StoryCardFilmState film;
  final StoryCardType cardType;
  final StoryCardCharacterComposition? characterComposition;
}
