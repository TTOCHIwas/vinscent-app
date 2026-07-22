import 'package:camera/camera.dart';

abstract final class StoryCardCameraPolicy {
  static CameraDescription select(
    List<CameraDescription> cameras, {
    String? preferredCameraName,
  }) {
    if (cameras.isEmpty) {
      throw StateError('No camera is available.');
    }

    if (preferredCameraName != null) {
      for (final camera in cameras) {
        if (camera.name == preferredCameraName) {
          return camera;
        }
      }
    }

    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.back) {
        return camera;
      }
    }
    return cameras.first;
  }

  static CameraDescription? alternate({
    required List<CameraDescription> cameras,
    required CameraDescription current,
  }) {
    final targetDirection = switch (current.lensDirection) {
      CameraLensDirection.front => CameraLensDirection.back,
      CameraLensDirection.back => CameraLensDirection.front,
      CameraLensDirection.external => CameraLensDirection.back,
    };

    for (final camera in cameras) {
      if (camera.lensDirection == targetDirection) {
        return camera;
      }
    }
    return null;
  }

  static double initialZoom({
    required double minimum,
    required double maximum,
  }) {
    return _clampZoom(1, minimum: minimum, maximum: maximum);
  }

  static double scaledZoom({
    required double baseZoom,
    required double gestureScale,
    required double minimum,
    required double maximum,
  }) {
    final normalizedBase = baseZoom.isFinite ? baseZoom : 1.0;
    final normalizedScale = gestureScale.isFinite && gestureScale > 0
        ? gestureScale
        : 1.0;
    return _clampZoom(
      normalizedBase * normalizedScale,
      minimum: minimum,
      maximum: maximum,
    );
  }

  static double _clampZoom(
    double value, {
    required double minimum,
    required double maximum,
  }) {
    if (!minimum.isFinite || !maximum.isFinite || minimum > maximum) {
      throw ArgumentError('Invalid camera zoom range: $minimum...$maximum');
    }
    return value.clamp(minimum, maximum).toDouble();
  }
}
