import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_camera_policy.dart';

void main() {
  const backCamera = CameraDescription(
    name: 'back',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );
  const frontCamera = CameraDescription(
    name: 'front',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 270,
  );
  const externalCamera = CameraDescription(
    name: 'external',
    lensDirection: CameraLensDirection.external,
    sensorOrientation: 0,
  );

  group('StoryCardCameraPolicy.select', () {
    test('처음 열 때 후면 카메라를 우선한다', () {
      final selected = StoryCardCameraPolicy.select(const [
        frontCamera,
        backCamera,
      ]);

      expect(selected, backCamera);
    });

    test('앱 복귀 시 기존 카메라를 유지한다', () {
      final selected = StoryCardCameraPolicy.select(const [
        backCamera,
        frontCamera,
      ], preferredCameraName: frontCamera.name);

      expect(selected, frontCamera);
    });

    test('후면 카메라가 없으면 첫 번째 카메라를 사용한다', () {
      final selected = StoryCardCameraPolicy.select(const [
        externalCamera,
        frontCamera,
      ]);

      expect(selected, externalCamera);
    });
  });

  group('StoryCardCameraPolicy.alternate', () {
    test('후면에서는 전면으로 전환한다', () {
      final alternate = StoryCardCameraPolicy.alternate(
        cameras: const [backCamera, frontCamera],
        current: backCamera,
      );

      expect(alternate, frontCamera);
    });

    test('전면에서는 후면으로 전환한다', () {
      final alternate = StoryCardCameraPolicy.alternate(
        cameras: const [frontCamera, backCamera],
        current: frontCamera,
      );

      expect(alternate, backCamera);
    });

    test('반대 방향 카메라가 없으면 전환하지 않는다', () {
      final alternate = StoryCardCameraPolicy.alternate(
        cameras: const [backCamera, externalCamera],
        current: backCamera,
      );

      expect(alternate, isNull);
    });
  });

  group('StoryCardCameraPolicy zoom', () {
    test('기본 배율 1을 기기 범위 안으로 제한한다', () {
      expect(StoryCardCameraPolicy.initialZoom(minimum: 0.5, maximum: 8), 1);
      expect(StoryCardCameraPolicy.initialZoom(minimum: 2, maximum: 8), 2);
    });

    test('핀치 배율을 시작 배율에 적용한다', () {
      final zoom = StoryCardCameraPolicy.scaledZoom(
        baseZoom: 2,
        gestureScale: 1.5,
        minimum: 1,
        maximum: 8,
      );

      expect(zoom, 3);
    });

    test('핀치 결과를 기기 최소·최대 배율로 제한한다', () {
      expect(
        StoryCardCameraPolicy.scaledZoom(
          baseZoom: 4,
          gestureScale: 4,
          minimum: 1,
          maximum: 8,
        ),
        8,
      );
      expect(
        StoryCardCameraPolicy.scaledZoom(
          baseZoom: 2,
          gestureScale: 0.1,
          minimum: 1,
          maximum: 8,
        ),
        1,
      );
    });
  });
}
