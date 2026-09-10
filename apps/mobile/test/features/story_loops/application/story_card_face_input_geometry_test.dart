import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_face_input_geometry.dart';

void main() {
  group('rotationDegrees', () {
    test('Android 후면 카메라는 기기 방향을 센서 방향에서 뺀다', () {
      expect(
        StoryCardFaceInputGeometry.rotationDegrees(
          platform: TargetPlatform.android,
          sensorOrientation: 90,
          lensDirection: CameraLensDirection.back,
          deviceOrientation: DeviceOrientation.landscapeLeft,
        ),
        0,
      );
    });

    test('Android 전면 카메라는 기기 방향을 센서 방향에 더한다', () {
      expect(
        StoryCardFaceInputGeometry.rotationDegrees(
          platform: TargetPlatform.android,
          sensorOrientation: 270,
          lensDirection: CameraLensDirection.front,
          deviceOrientation: DeviceOrientation.landscapeLeft,
        ),
        0,
      );
    });

    test('iOS는 센서 방향을 그대로 사용한다', () {
      expect(
        StoryCardFaceInputGeometry.rotationDegrees(
          platform: TargetPlatform.iOS,
          sensorOrientation: 90,
          lensDirection: CameraLensDirection.front,
          deviceOrientation: DeviceOrientation.landscapeRight,
        ),
        90,
      );
    });
  });

  group('normalizeBoundingBox', () {
    test('Android 90도 입력은 회전된 너비와 높이로 정규화한다', () {
      final result = StoryCardFaceInputGeometry.normalizeBoundingBox(
        boundingBox: const Rect.fromLTRB(72, 128, 216, 384),
        imageSize: const Size(1280, 720),
        rotationDegrees: 90,
        platform: TargetPlatform.android,
        lensDirection: CameraLensDirection.back,
      );

      expect(result.left, closeTo(0.1, 0.0001));
      expect(result.right, closeTo(0.3, 0.0001));
      expect(result.top, closeTo(0.1, 0.0001));
      expect(result.bottom, closeTo(0.3, 0.0001));
    });

    test('Android 270도 입력은 미리보기의 가로 방향을 반전한다', () {
      final result = StoryCardFaceInputGeometry.normalizeBoundingBox(
        boundingBox: const Rect.fromLTRB(72, 128, 216, 384),
        imageSize: const Size(1280, 720),
        rotationDegrees: 270,
        platform: TargetPlatform.android,
        lensDirection: CameraLensDirection.front,
      );

      expect(result.left, closeTo(0.7, 0.0001));
      expect(result.right, closeTo(0.9, 0.0001));
      expect(result.top, closeTo(0.1, 0.0001));
      expect(result.bottom, closeTo(0.3, 0.0001));
    });

    test('iOS 입력은 회전값과 무관하게 원본 크기로 정규화한다', () {
      final result = StoryCardFaceInputGeometry.normalizeBoundingBox(
        boundingBox: const Rect.fromLTRB(128, 72, 384, 216),
        imageSize: const Size(1280, 720),
        rotationDegrees: 90,
        platform: TargetPlatform.iOS,
        lensDirection: CameraLensDirection.back,
      );

      expect(result, const Rect.fromLTRB(0.1, 0.1, 0.3, 0.3));
    });
  });
}
