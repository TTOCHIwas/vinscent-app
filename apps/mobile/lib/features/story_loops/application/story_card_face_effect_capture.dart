import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as image;

import 'story_card_face_detector.dart';
import 'story_card_face_effect.dart';

class StoryCardFaceNotFoundException implements Exception {
  const StoryCardFaceNotFoundException();
}

class StoryCardFaceEffectCapture {
  const StoryCardFaceEffectCapture({required this.detector});

  final StoryCardFaceDetector detector;

  Future<StoryCardCharacterComposition> detectComposition({
    required String imagePath,
    required Uint8List imageBytes,
    required StoryCardCharacterAsset character,
    StoryCardCharacterSide? characterSide,
  }) async {
    final decoded = image.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Unsupported image format.');
    }
    final upright = image.bakeOrientation(decoded);
    final observations = await detector.detectFile(
      path: imagePath,
      uprightSize: Size(upright.width.toDouble(), upright.height.toDouble()),
    );
    final detectedFace = StoryCardFaceObservation.primary(observations);
    final face = detectedFace == null || characterSide == null
        ? detectedFace
        : detectedFace.withCharacterSide(characterSide);
    if (face == null) {
      throw const StoryCardFaceNotFoundException();
    }
    return StoryCardCharacterComposition(asset: character, face: face);
  }
}
