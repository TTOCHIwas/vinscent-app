import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_face_mesh_geometry.dart';

void main() {
  test('랜드마크에서 얼굴 범위와 좌우 부착 기준점을 추출한다', () {
    final landmarks = List<Offset>.filled(
      478,
      const Offset(0.5, 0.5),
      growable: false,
    );
    landmarks[10] = const Offset(0.5, 0.2);
    landmarks[152] = const Offset(0.5, 0.72);
    landmarks[234] = const Offset(0.3, 0.45);
    landmarks[454] = const Offset(0.7, 0.46);
    landmarks[33] = const Offset(0.38, 0.4);
    landmarks[263] = const Offset(0.62, 0.42);

    final observation = StoryCardFaceMeshGeometry.fromNormalizedLandmarks(
      landmarks,
    );

    expect(observation, isNotNull);
    expect(observation!.normalizedBounds.left, closeTo(0.3, 0.0001));
    expect(observation.normalizedBounds.top, closeTo(0.2, 0.0001));
    expect(observation.normalizedBounds.right, closeTo(0.7, 0.0001));
    expect(observation.normalizedBounds.bottom, closeTo(0.72, 0.0001));
    expect(observation.normalizedLeftAnchor, const Offset(0.3, 0.45));
    expect(observation.normalizedRightAnchor, const Offset(0.7, 0.46));
    expect(observation.rollRadians, closeTo(math.atan2(0.02, 0.24), 0.0001));
  });

  test('필요한 인덱스가 없는 랜드마크 결과는 무시한다', () {
    final observation = StoryCardFaceMeshGeometry.fromNormalizedLandmarks(
      const [Offset(0.4, 0.4), Offset(0.6, 0.6)],
    );

    expect(observation, isNull);
  });

  test('픽셀 좌표 랜드마크를 검출 이미지 크기에 맞춰 정규화한다', () {
    final landmarks = List<Offset>.filled(
      468,
      const Offset(500, 500),
      growable: false,
    );
    landmarks[10] = const Offset(500, 200);
    landmarks[152] = const Offset(500, 720);
    landmarks[234] = const Offset(300, 450);
    landmarks[454] = const Offset(700, 460);
    landmarks[33] = const Offset(380, 400);
    landmarks[263] = const Offset(620, 420);

    final observation = StoryCardFaceMeshGeometry.fromPixelLandmarks(
      landmarks,
      const Size(1000, 1000),
    );

    expect(observation, isNotNull);
    expect(
      observation!.normalizedBounds,
      const Rect.fromLTRB(0.3, 0.2, 0.7, 0.72),
    );
    expect(observation.normalizedLeftAnchor, const Offset(0.3, 0.45));
    expect(observation.normalizedRightAnchor, const Offset(0.7, 0.46));
  });

  test('유효하지 않은 검출 이미지 크기의 픽셀 좌표는 무시한다', () {
    final landmarks = List<Offset>.filled(
      468,
      const Offset(1, 1),
      growable: false,
    );

    expect(
      StoryCardFaceMeshGeometry.fromPixelLandmarks(landmarks, Size.zero),
      isNull,
    );
  });
}
