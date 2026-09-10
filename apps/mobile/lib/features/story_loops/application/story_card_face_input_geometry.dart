import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

abstract final class StoryCardFaceInputGeometry {
  static const _orientationDegrees = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  static int rotationDegrees({
    required TargetPlatform platform,
    required int sensorOrientation,
    required CameraLensDirection lensDirection,
    required DeviceOrientation deviceOrientation,
  }) {
    final normalizedSensorOrientation = sensorOrientation % 360;
    if (platform == TargetPlatform.iOS) {
      return normalizedSensorOrientation;
    }
    if (platform != TargetPlatform.android) {
      return normalizedSensorOrientation;
    }

    final deviceDegrees = _orientationDegrees[deviceOrientation] ?? 0;
    return lensDirection == CameraLensDirection.front
        ? (normalizedSensorOrientation + deviceDegrees) % 360
        : (normalizedSensorOrientation - deviceDegrees + 360) % 360;
  }

  static Rect normalizeBoundingBox({
    required Rect boundingBox,
    required Size imageSize,
    required int rotationDegrees,
    required TargetPlatform platform,
    required CameraLensDirection lensDirection,
  }) {
    if (imageSize.isEmpty) {
      return Rect.zero;
    }

    final left = _normalizeX(
      boundingBox.left,
      imageSize: imageSize,
      rotationDegrees: rotationDegrees,
      platform: platform,
      lensDirection: lensDirection,
    );
    final right = _normalizeX(
      boundingBox.right,
      imageSize: imageSize,
      rotationDegrees: rotationDegrees,
      platform: platform,
      lensDirection: lensDirection,
    );
    final top = _normalizeY(
      boundingBox.top,
      imageSize: imageSize,
      rotationDegrees: rotationDegrees,
      platform: platform,
    );
    final bottom = _normalizeY(
      boundingBox.bottom,
      imageSize: imageSize,
      rotationDegrees: rotationDegrees,
      platform: platform,
    );

    return Rect.fromLTRB(
      math.min(left, right).clamp(0.0, 1.0).toDouble(),
      math.min(top, bottom).clamp(0.0, 1.0).toDouble(),
      math.max(left, right).clamp(0.0, 1.0).toDouble(),
      math.max(top, bottom).clamp(0.0, 1.0).toDouble(),
    );
  }

  static double _normalizeX(
    double x, {
    required Size imageSize,
    required int rotationDegrees,
    required TargetPlatform platform,
    required CameraLensDirection lensDirection,
  }) {
    return switch (rotationDegrees) {
      90 =>
        x /
            (platform == TargetPlatform.iOS
                ? imageSize.width
                : imageSize.height),
      270 =>
        1 -
            x /
                (platform == TargetPlatform.iOS
                    ? imageSize.width
                    : imageSize.height),
      _ =>
        lensDirection == CameraLensDirection.back
            ? x / imageSize.width
            : 1 - x / imageSize.width,
    };
  }

  static double _normalizeY(
    double y, {
    required Size imageSize,
    required int rotationDegrees,
    required TargetPlatform platform,
  }) {
    return switch (rotationDegrees) {
      90 || 270 =>
        y /
            (platform == TargetPlatform.iOS
                ? imageSize.height
                : imageSize.width),
      _ => y / imageSize.height,
    };
  }
}
