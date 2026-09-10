import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'story_card_face_effect.dart';
import 'story_card_face_input_geometry.dart';

abstract interface class StoryCardFaceDetector {
  Future<List<StoryCardFaceObservation>> detectCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  });

  Future<List<StoryCardFaceObservation>> detectFile({
    required String path,
    required Size uprightSize,
  });

  Future<void> close();
}

abstract interface class StoryCardFaceDetectorTiming {
  Duration get minimumDetectionInterval;

  double get observationSmoothingFactor;
}

class MlKitStoryCardFaceDetector implements StoryCardFaceDetector {
  MlKitStoryCardFaceDetector({TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform,
      _detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          enableTracking: true,
          minFaceSize: 0.12,
        ),
      );

  final TargetPlatform _platform;
  final FaceDetector _detector;

  @override
  Future<List<StoryCardFaceObservation>> detectCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    final input = _cameraInput(
      image: image,
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (input == null) {
      return const [];
    }

    final faces = await _detector.processImage(input.image);
    return _validObservations(
      faces.map(
        (face) => StoryCardFaceObservation(
          normalizedBounds: StoryCardFaceInputGeometry.normalizeBoundingBox(
            boundingBox: face.boundingBox,
            imageSize: input.imageSize,
            rotationDegrees: input.rotationDegrees,
            platform: _platform,
            lensDirection: camera.lensDirection,
          ),
        ),
      ),
    );
  }

  @override
  Future<List<StoryCardFaceObservation>> detectFile({
    required String path,
    required Size uprightSize,
  }) async {
    if (uprightSize.isEmpty) {
      return const [];
    }

    final faces = await _detector.processImage(InputImage.fromFilePath(path));
    return _validObservations(
      faces.map(
        (face) => StoryCardFaceObservation(
          normalizedBounds: Rect.fromLTRB(
            face.boundingBox.left / uprightSize.width,
            face.boundingBox.top / uprightSize.height,
            face.boundingBox.right / uprightSize.width,
            face.boundingBox.bottom / uprightSize.height,
          ),
        ),
      ),
    );
  }

  @override
  Future<void> close() => _detector.close();

  _StoryCardCameraInput? _cameraInput({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    if (_platform != TargetPlatform.android &&
        _platform != TargetPlatform.iOS) {
      return null;
    }

    final rotationDegrees = StoryCardFaceInputGeometry.rotationDegrees(
      platform: _platform,
      sensorOrientation: camera.sensorOrientation,
      lensDirection: camera.lensDirection,
      deviceOrientation: deviceOrientation,
    );
    final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final expectedFormat = _platform == TargetPlatform.android
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;
    if (rotation == null ||
        format != expectedFormat ||
        image.planes.length != 1) {
      return null;
    }

    final plane = image.planes.first;
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    return _StoryCardCameraInput(
      image: InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: format!,
          bytesPerRow: plane.bytesPerRow,
        ),
      ),
      imageSize: imageSize,
      rotationDegrees: rotationDegrees,
    );
  }

  List<StoryCardFaceObservation> _validObservations(
    Iterable<StoryCardFaceObservation> observations,
  ) {
    return observations
        .where((observation) {
          final bounds = observation.normalizedBounds;
          return bounds.width > 0 && bounds.height > 0 && bounds.isFinite;
        })
        .toList(growable: false);
  }
}

class _StoryCardCameraInput {
  const _StoryCardCameraInput({
    required this.image,
    required this.imageSize,
    required this.rotationDegrees,
  });

  final InputImage image;
  final Size imageSize;
  final int rotationDegrees;
}
