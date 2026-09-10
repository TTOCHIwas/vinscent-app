import 'dart:ui';

import 'package:camera/camera.dart';

enum StoryCardCameraSwipeAction { none, nextFilm, previousFilm, switchCamera }

abstract final class StoryCardCameraPolicy {
  static const _minimumSwipeDistance = 56.0;
  static const _minimumFlingDistance = 24.0;
  static const _minimumFlingVelocity = 700.0;
  static const _axisDominanceRatio = 1.25;

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

  static FlashMode nextFlashMode(FlashMode current) {
    return switch (current) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      FlashMode.always || FlashMode.torch => FlashMode.off,
    };
  }

  static StoryCardCameraSwipeAction classifySwipe({
    required Offset displacement,
    required Offset velocity,
    required int pointerCount,
  }) {
    if (pointerCount != 1) {
      return StoryCardCameraSwipeAction.none;
    }

    final horizontalDistance = displacement.dx.abs();
    final verticalDistance = displacement.dy.abs();
    final primaryDistance = horizontalDistance > verticalDistance
        ? horizontalDistance
        : verticalDistance;
    if (primaryDistance < _minimumSwipeDistance) {
      final primaryVelocity = horizontalDistance > verticalDistance
          ? velocity.dx.abs()
          : velocity.dy.abs();
      if (primaryDistance < _minimumFlingDistance ||
          primaryVelocity < _minimumFlingVelocity) {
        return StoryCardCameraSwipeAction.none;
      }
    }

    if (horizontalDistance >= verticalDistance * _axisDominanceRatio) {
      return displacement.dx < 0
          ? StoryCardCameraSwipeAction.nextFilm
          : StoryCardCameraSwipeAction.previousFilm;
    }
    if (verticalDistance >= horizontalDistance * _axisDominanceRatio) {
      return StoryCardCameraSwipeAction.switchCamera;
    }
    return StoryCardCameraSwipeAction.none;
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
