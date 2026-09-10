import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../application/story_card_face_detector.dart';
import '../../application/story_card_face_effect.dart';
import '../../application/story_card_face_tracking_policy.dart';

class StoryCardCameraFaceTracker {
  StoryCardCameraFaceTracker({
    required this.detector,
    required this.onFaceChanged,
    Duration? minimumDetectionInterval,
    StoryCardFaceTrackingPolicy? trackingPolicy,
  }) : minimumDetectionInterval =
           minimumDetectionInterval ?? _minimumDetectionIntervalFor(detector),
       _trackingPolicy =
           trackingPolicy ??
           StoryCardFaceTrackingPolicy(
             smoothingFactor: _observationSmoothingFactorFor(detector),
           );

  final StoryCardFaceDetector detector;
  final ValueChanged<StoryCardFaceObservation?> onFaceChanged;
  final Duration minimumDetectionInterval;
  final StoryCardFaceTrackingPolicy _trackingPolicy;

  CameraController? _controller;
  Future<void>? _pendingDetection;
  DateTime? _lastDetectionStartedAt;
  int _generation = 0;

  Future<void> start(CameraController controller) async {
    if (_controller == controller && controller.value.isStreamingImages) {
      return;
    }

    await stop();
    if (!controller.value.isInitialized) {
      return;
    }

    final generation = ++_generation;
    _controller = controller;
    _trackingPolicy.reset();
    _lastDetectionStartedAt = null;
    try {
      await controller.startImageStream(
        (image) => _handleImage(image, controller, generation),
      );
    } catch (error) {
      if (generation == _generation) {
        _controller = null;
      }
      _logFailure('start', error);
    }
  }

  Future<void> stop() async {
    _generation += 1;
    final controller = _controller;
    _controller = null;
    _lastDetectionStartedAt = null;
    _trackingPolicy.reset();
    onFaceChanged(null);

    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (error) {
        _logFailure('stop', error);
      }
    }

    try {
      await _pendingDetection;
    } catch (_) {}
    _pendingDetection = null;
  }

  void _handleImage(
    CameraImage image,
    CameraController controller,
    int generation,
  ) {
    if (generation != _generation ||
        _controller != controller ||
        _pendingDetection != null) {
      return;
    }

    final now = DateTime.now();
    final previousStartedAt = _lastDetectionStartedAt;
    if (previousStartedAt != null &&
        now.difference(previousStartedAt) < minimumDetectionInterval) {
      return;
    }
    _lastDetectionStartedAt = now;

    late final Future<void> pending;
    pending = _detect(image, controller, generation).whenComplete(() {
      if (identical(_pendingDetection, pending)) {
        _pendingDetection = null;
      }
    });
    _pendingDetection = pending;
  }

  Future<void> _detect(
    CameraImage image,
    CameraController controller,
    int generation,
  ) async {
    StoryCardFaceObservation? observation;
    try {
      final observations = await detector.detectCameraImage(
        image: image,
        camera: controller.description,
        deviceOrientation: controller.value.deviceOrientation,
      );
      observation = StoryCardFaceObservation.primary(observations);
    } catch (error) {
      _logFailure('detection', error);
    }

    if (generation != _generation || _controller != controller) {
      return;
    }
    onFaceChanged(_trackingPolicy.update(observation));
  }

  Future<void> dispose() => stop();

  void _logFailure(String operation, Object error) {
    if (kDebugMode) {
      debugPrint('Story card face tracking $operation failed: $error');
    }
  }
}

Duration _minimumDetectionIntervalFor(StoryCardFaceDetector detector) {
  return detector is StoryCardFaceDetectorTiming
      ? (detector as StoryCardFaceDetectorTiming).minimumDetectionInterval
      : const Duration(milliseconds: 140);
}

double _observationSmoothingFactorFor(StoryCardFaceDetector detector) {
  return detector is StoryCardFaceDetectorTiming
      ? (detector as StoryCardFaceDetectorTiming).observationSmoothingFactor
      : 0.36;
}
