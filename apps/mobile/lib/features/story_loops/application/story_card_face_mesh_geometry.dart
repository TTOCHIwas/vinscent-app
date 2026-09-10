import 'dart:math' as math;
import 'dart:ui';

import 'story_card_face_effect.dart';

abstract final class StoryCardFaceMeshGeometry {
  static const _leftEyeOuterIndex = 33;
  static const _rightEyeOuterIndex = 263;
  static const _leftCheekIndex = 234;
  static const _rightCheekIndex = 454;
  static const _maximumRequiredIndex = _rightCheekIndex;
  static const _faceOvalIndices = <int>[
    10,
    338,
    297,
    332,
    284,
    251,
    389,
    356,
    454,
    323,
    361,
    288,
    397,
    365,
    379,
    378,
    400,
    377,
    152,
    148,
    176,
    149,
    150,
    136,
    172,
    58,
    132,
    93,
    234,
    127,
    162,
    21,
    54,
    103,
    67,
    109,
  ];

  static StoryCardFaceObservation? fromNormalizedLandmarks(
    List<Offset> landmarks,
  ) {
    if (landmarks.length <= _maximumRequiredIndex) {
      return null;
    }

    final oval = <Offset>[];
    for (final index in _faceOvalIndices) {
      final point = landmarks[index];
      if (!point.dx.isFinite || !point.dy.isFinite) {
        return null;
      }
      oval.add(point);
    }

    final leftEye = landmarks[_leftEyeOuterIndex];
    final rightEye = landmarks[_rightEyeOuterIndex];
    final firstCheek = landmarks[_leftCheekIndex];
    final secondCheek = landmarks[_rightCheekIndex];
    if (![
      leftEye,
      rightEye,
      firstCheek,
      secondCheek,
    ].every((point) => point.dx.isFinite && point.dy.isFinite)) {
      return null;
    }

    final left = oval.map((point) => point.dx).reduce(math.min);
    final top = oval.map((point) => point.dy).reduce(math.min);
    final right = oval.map((point) => point.dx).reduce(math.max);
    final bottom = oval.map((point) => point.dy).reduce(math.max);
    final bounds = Rect.fromLTRB(
      left.clamp(0.0, 1.0).toDouble(),
      top.clamp(0.0, 1.0).toDouble(),
      right.clamp(0.0, 1.0).toDouble(),
      bottom.clamp(0.0, 1.0).toDouble(),
    );
    if (bounds.width <= 0 || bounds.height <= 0 || !bounds.isFinite) {
      return null;
    }

    final cheeks = [firstCheek, secondCheek]
      ..sort((a, b) => a.dx.compareTo(b.dx));
    final visualEyes = [leftEye, rightEye]
      ..sort((a, b) => a.dx.compareTo(b.dx));
    final eyeDelta = visualEyes.last - visualEyes.first;

    return StoryCardFaceObservation(
      normalizedBounds: bounds,
      normalizedLeftAnchor: _clampPoint(cheeks.first),
      normalizedRightAnchor: _clampPoint(cheeks.last),
      rollRadians: math.atan2(eyeDelta.dy, eyeDelta.dx),
    );
  }

  static StoryCardFaceObservation? fromPixelLandmarks(
    List<Offset> landmarks,
    Size imageSize,
  ) {
    if (!imageSize.width.isFinite ||
        !imageSize.height.isFinite ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return null;
    }
    return fromNormalizedLandmarks([
      for (final landmark in landmarks)
        Offset(landmark.dx / imageSize.width, landmark.dy / imageSize.height),
    ]);
  }

  static Offset _clampPoint(Offset point) {
    return Offset(
      point.dx.clamp(0.0, 1.0).toDouble(),
      point.dy.clamp(0.0, 1.0).toDouble(),
    );
  }
}
