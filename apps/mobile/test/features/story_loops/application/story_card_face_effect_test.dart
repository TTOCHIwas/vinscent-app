import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/features/story_loops/application/story_card_face_effect.dart';

void main() {
  group('StoryCardFaceObservation', () {
    test('전면 카메라 미리보기 좌표를 좌우 반전한다', () {
      const face = StoryCardFaceObservation(
        normalizedBounds: Rect.fromLTWH(0.1, 0.2, 0.25, 0.3),
        normalizedLeftAnchor: Offset(0.12, 0.32),
        normalizedRightAnchor: Offset(0.32, 0.34),
        rollRadians: 0.2,
        characterSide: StoryCardCharacterSide.right,
      );

      final mirrored = face.mirroredHorizontally();

      expect(mirrored.normalizedBounds.left, closeTo(0.65, 0.0001));
      expect(mirrored.normalizedBounds.top, closeTo(0.2, 0.0001));
      expect(mirrored.normalizedBounds.width, closeTo(0.25, 0.0001));
      expect(mirrored.normalizedBounds.height, closeTo(0.3, 0.0001));
      expect(mirrored.normalizedLeftAnchor.dx, closeTo(0.68, 0.0001));
      expect(mirrored.normalizedLeftAnchor.dy, closeTo(0.34, 0.0001));
      expect(mirrored.normalizedRightAnchor.dx, closeTo(0.88, 0.0001));
      expect(mirrored.normalizedRightAnchor.dy, closeTo(0.32, 0.0001));
      expect(mirrored.rollRadians, closeTo(-0.2, 0.0001));
      expect(mirrored.characterSide, StoryCardCharacterSide.left);
    });

    test('여러 얼굴 중 가장 큰 얼굴을 대표 얼굴로 고른다', () {
      const small = StoryCardFaceObservation(
        normalizedBounds: Rect.fromLTWH(0.1, 0.1, 0.15, 0.2),
      );
      const large = StoryCardFaceObservation(
        normalizedBounds: Rect.fromLTWH(0.45, 0.2, 0.3, 0.35),
      );

      expect(StoryCardFaceObservation.primary([small, large]), same(large));
    });
  });

  group('StoryCardCharacterPlacement', () {
    test('캐릭터를 머리 위 중앙에 배치한다', () {
      const face = StoryCardFaceObservation(
        normalizedBounds: Rect.fromLTWH(0.25, 0.3, 0.22, 0.24),
      );

      final placement = StoryCardCharacterPlacement.calculate(
        face: face,
        characterAspectRatio: 1,
        viewportSize: const Size(1080, 1920),
      );

      expect(
        placement.center.dx,
        closeTo(face.normalizedBounds.center.dx, 0.0001),
      );
      expect(placement.bottom, closeTo(face.normalizedBounds.top, 0.0001));
      expect(placement.top, greaterThanOrEqualTo(0.02));
    });

    test('머리 위 공간이 부족하면 캐릭터를 숨긴다', () {
      const face = StoryCardFaceObservation(
        normalizedBounds: Rect.fromLTWH(0.4, 0.08, 0.2, 0.25),
      );

      final placement = StoryCardCharacterPlacement.calculate(
        face: face,
        characterAspectRatio: 1,
        viewportSize: const Size(1080, 1920),
      );

      expect(placement, Rect.zero);
    });

    test('볼 기준점과 좌우 배치값에 관계없이 머리 위에 배치한다', () {
      const face = StoryCardFaceObservation(
        normalizedBounds: Rect.fromLTWH(0.25, 0.3, 0.22, 0.24),
        normalizedRightAnchor: Offset(0.9, 0.8),
        characterSide: StoryCardCharacterSide.right,
      );

      final placement = StoryCardCharacterPlacement.calculate(
        face: face,
        characterAspectRatio: 1,
        viewportSize: const Size(1080, 1920),
      );

      expect(
        placement.center.dx,
        closeTo(face.normalizedBounds.center.dx, 0.0001),
      );
      expect(placement.bottom, closeTo(face.normalizedBounds.top, 0.0001));
    });
  });

  test('투명 캐릭터 이미지를 배경에 합성한다', () {
    final background = image.Image(width: 120, height: 200);
    image.fill(background, color: image.ColorRgb8(255, 255, 255));
    final character = image.Image(width: 20, height: 20, numChannels: 4);
    image.fill(character, color: image.ColorRgba8(230, 30, 40, 255));

    final result = const StoryCardCharacterCompositor().composite(
      background: background,
      characterBytes: Uint8List.fromList(image.encodePng(character)),
      normalizedPlacement: const Rect.fromLTWH(0.25, 0.3, 0.3, 0.2),
    );

    final compositedPixel = result.getPixel(40, 70);
    final untouchedPixel = result.getPixel(5, 5);
    expect(compositedPixel.r, greaterThan(200));
    expect(compositedPixel.g, lessThan(80));
    expect(compositedPixel.b, lessThan(80));
    expect(untouchedPixel.r, 255);
    expect(untouchedPixel.g, 255);
    expect(untouchedPixel.b, 255);
  });
}
