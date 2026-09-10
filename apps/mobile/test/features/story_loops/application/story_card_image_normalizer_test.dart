import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/features/story_loops/application/story_card_face_effect.dart';
import 'package:vinscent/features/story_loops/application/story_card_image_normalizer.dart';

void main() {
  const normalizer = StoryCardImageNormalizer();

  test(
    'normalizes a large image to JPEG within the maximum dimension',
    () async {
      final source = image.Image(width: 2400, height: 1200);

      final result = await normalizer.normalize(
        Uint8List.fromList(image.encodePng(source)),
      );
      final decoded = image.decodeImage(result);

      expect(decoded, isNotNull);
      expect(decoded!.width, 2048);
      expect(decoded.height, 1024);
      expect(result[0], 0xFF);
      expect(result[1], 0xD8);
    },
  );

  test('rejects bytes that are not a supported image', () async {
    expect(
      () => normalizer.normalize(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });

  test('정규화 과정에서 선택한 커플 캐릭터를 한 번에 합성한다', () async {
    final source = image.Image(width: 120, height: 200);
    image.fill(source, color: image.ColorRgb8(255, 255, 255));
    final character = image.Image(width: 20, height: 20, numChannels: 4);
    image.fill(character, color: image.ColorRgba8(230, 30, 40, 255));
    final asset = StoryCardCharacterAsset.fromBytes(
      Uint8List.fromList(image.encodePng(character)),
    );

    final result = await normalizer.normalize(
      Uint8List.fromList(image.encodePng(source)),
      characterComposition: StoryCardCharacterComposition(
        asset: asset,
        face: const StoryCardFaceObservation(
          normalizedBounds: Rect.fromLTWH(0.1, 0.35, 0.2, 0.22),
        ),
      ),
    );
    final decoded = image.decodeImage(result)!;

    final containsCharacterColor = decoded.any(
      (pixel) => pixel.r > 170 && pixel.g < 110 && pixel.b < 110,
    );
    expect(containsCharacterColor, isTrue);
  });

  test('머리 위 공간이 없으면 촬영 결과에 캐릭터를 합성하지 않는다', () async {
    final source = image.Image(width: 120, height: 200);
    image.fill(source, color: image.ColorRgb8(255, 255, 255));
    final character = image.Image(width: 20, height: 20, numChannels: 4);
    image.fill(character, color: image.ColorRgba8(230, 30, 40, 255));
    final asset = StoryCardCharacterAsset.fromBytes(
      Uint8List.fromList(image.encodePng(character)),
    );

    final result = await normalizer.normalize(
      Uint8List.fromList(image.encodePng(source)),
      characterComposition: StoryCardCharacterComposition(
        asset: asset,
        face: const StoryCardFaceObservation(
          normalizedBounds: Rect.fromLTWH(0.4, 0.08, 0.2, 0.22),
        ),
      ),
    );
    final decoded = image.decodeImage(result)!;

    final containsCharacterColor = decoded.any(
      (pixel) => pixel.r > 170 && pixel.g < 110 && pixel.b < 110,
    );
    expect(containsCharacterColor, isFalse);
  });
}
