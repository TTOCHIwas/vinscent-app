import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/features/story_loops/application/story_card_face_detector.dart';
import 'package:vinscent/features/story_loops/application/story_card_face_effect.dart';
import 'package:vinscent/features/story_loops/application/story_card_face_effect_capture.dart';

void main() {
  test('촬영 파일에서 가장 큰 얼굴과 캐릭터를 저장용 합성 정보로 묶는다', () async {
    final detector = _FakeFaceDetector([
      const StoryCardFaceObservation(
        normalizedBounds: Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
      ),
      const StoryCardFaceObservation(
        normalizedBounds: Rect.fromLTWH(0.3, 0.2, 0.3, 0.3),
      ),
    ]);
    final source = image.Image(width: 120, height: 200);
    final character = image.Image(width: 20, height: 20, numChannels: 4);
    image.fill(character, color: image.ColorRgba8(230, 30, 40, 255));
    final asset = StoryCardCharacterAsset.fromBytes(
      Uint8List.fromList(image.encodePng(character)),
    );

    final result = await StoryCardFaceEffectCapture(detector: detector)
        .detectComposition(
          imagePath: 'capture.jpg',
          imageBytes: Uint8List.fromList(image.encodeJpg(source)),
          character: asset,
        );

    expect(detector.lastPath, 'capture.jpg');
    expect(detector.lastUprightSize, const Size(120, 200));
    expect(result.face, same(detector.observations.last));
    expect(result.asset, same(asset));
  });

  test('촬영 파일에서 얼굴을 찾지 못하면 결과 생성을 중단한다', () async {
    final source = image.Image(width: 120, height: 200);
    final character = image.Image(width: 20, height: 20, numChannels: 4);
    final asset = StoryCardCharacterAsset.fromBytes(
      Uint8List.fromList(image.encodePng(character)),
    );

    expect(
      () => StoryCardFaceEffectCapture(detector: _FakeFaceDetector(const []))
          .detectComposition(
            imagePath: 'capture.jpg',
            imageBytes: Uint8List.fromList(image.encodeJpg(source)),
            character: asset,
          ),
      throwsA(isA<StoryCardFaceNotFoundException>()),
    );
  });

  test('미리보기에서 정한 캐릭터 부착 방향을 저장 결과에 유지한다', () async {
    final source = image.Image(width: 120, height: 200);
    final character = image.Image(width: 20, height: 20, numChannels: 4);
    final asset = StoryCardCharacterAsset.fromBytes(
      Uint8List.fromList(image.encodePng(character)),
    );
    final detector = _FakeFaceDetector([
      const StoryCardFaceObservation(
        normalizedBounds: Rect.fromLTWH(0.72, 0.2, 0.2, 0.3),
      ),
    ]);

    final result = await StoryCardFaceEffectCapture(detector: detector)
        .detectComposition(
          imagePath: 'capture.jpg',
          imageBytes: Uint8List.fromList(image.encodeJpg(source)),
          character: asset,
          characterSide: StoryCardCharacterSide.right,
        );

    expect(result.face.characterSide, StoryCardCharacterSide.right);
  });
}

class _FakeFaceDetector implements StoryCardFaceDetector {
  _FakeFaceDetector(this.observations);

  final List<StoryCardFaceObservation> observations;
  String? lastPath;
  Size? lastUprightSize;

  @override
  Future<List<StoryCardFaceObservation>> detectCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async => const [];

  @override
  Future<List<StoryCardFaceObservation>> detectFile({
    required String path,
    required Size uprightSize,
  }) async {
    lastPath = path;
    lastUprightSize = uprightSize;
    return observations;
  }

  @override
  Future<void> close() async {}
}
