import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
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
}
