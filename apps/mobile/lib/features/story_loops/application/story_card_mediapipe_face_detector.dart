import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart'
    as face_tflite;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_litert/native.dart' as litert;

import 'story_card_face_detector.dart';
import 'story_card_face_effect.dart';
import 'story_card_face_input_geometry.dart';
import 'story_card_face_mesh_geometry.dart';

class MediaPipeStoryCardFaceDetector
    implements StoryCardFaceDetector, StoryCardFaceDetectorTiming {
  MediaPipeStoryCardFaceDetector({
    required StoryCardFaceDetector fallback,
    TargetPlatform? platform,
  }) : _fallback = fallback,
       _platform = platform ?? defaultTargetPlatform;

  static const _maximumTrackedFaceMisses = 3;

  final StoryCardFaceDetector _fallback;
  final TargetPlatform _platform;
  final _StoryCardFaceMeshDiagnostics _diagnostics =
      _StoryCardFaceMeshDiagnostics();

  face_tflite.FaceDetector? _detector;
  Future<face_tflite.FaceDetector>? _detectorInitialization;
  String? _cameraName;
  int? _selectedTrackingId;
  int _selectedFaceMisses = 0;
  bool _mediaPipeDisabled = false;
  bool _closed = false;

  @override
  Duration get minimumDetectionInterval => const Duration(milliseconds: 16);

  @override
  double get observationSmoothingFactor => 0.58;

  @override
  Future<List<StoryCardFaceObservation>> detectCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    if (_closed) {
      return const [];
    }
    final frame = _cameraFrame(
      image: image,
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (_mediaPipeDisabled || frame == null) {
      return _fallback.detectCameraImage(
        image: image,
        camera: camera,
        deviceOrientation: deviceOrientation,
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final detector = await _ensureDetector();
      _resetTrackingWhenCameraChanges(detector, camera.name);
      final faces = await detector.detectFacesFromCameraFrame(
        frame,
        mode: face_tflite.FaceDetectionMode.standard,
        maxDim: 640,
      );
      stopwatch.stop();
      _diagnostics.record(stopwatch.elapsedMicroseconds);

      final selectedFace = _selectTrackedFace(faces);
      final observation = selectedFace == null
          ? null
          : _observationFromFace(selectedFace);
      final visibleObservation =
          camera.lensDirection == CameraLensDirection.front
          ? observation?.mirroredHorizontally()
          : observation;
      return visibleObservation == null ? const [] : [visibleObservation];
    } catch (error, stackTrace) {
      await _disableMediaPipe(error, stackTrace);
      return _fallback.detectCameraImage(
        image: image,
        camera: camera,
        deviceOrientation: deviceOrientation,
      );
    }
  }

  @override
  Future<List<StoryCardFaceObservation>> detectFile({
    required String path,
    required Size uprightSize,
  }) async {
    if (_closed) {
      return const [];
    }
    if (_mediaPipeDisabled) {
      return _fallback.detectFile(path: path, uprightSize: uprightSize);
    }

    try {
      final detector = await _ensureDetector();
      detector.resetTracking();
      _clearSelectedFace();
      final faces = await detector.detectFacesFromFilepath(
        path,
        mode: face_tflite.FaceDetectionMode.standard,
      );
      final selectedFace = _largestFace(faces);
      final observation = selectedFace == null
          ? null
          : _observationFromFace(selectedFace);
      detector.resetTracking();
      _clearSelectedFace();
      return observation == null ? const [] : [observation];
    } catch (error, stackTrace) {
      await _disableMediaPipe(error, stackTrace);
      return _fallback.detectFile(path: path, uprightSize: uprightSize);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;

    final initialization = _detectorInitialization;
    if (initialization != null) {
      try {
        await (await initialization).dispose();
      } catch (_) {}
    } else {
      await _detector?.dispose();
    }
    _detector = null;
    _detectorInitialization = null;
    await _fallback.close();
  }

  litert.CameraFrame? _cameraFrame({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    if (image.width <= 0 || image.height <= 0 || image.planes.isEmpty) {
      return null;
    }

    final rotation = _cameraFrameRotation(
      StoryCardFaceInputGeometry.rotationDegrees(
        platform: _platform,
        sensorOrientation: camera.sensorOrientation,
        lensDirection: camera.lensDirection,
        deviceOrientation: deviceOrientation,
      ),
    );

    if (_platform == TargetPlatform.android && image.planes.length == 1) {
      final plane = image.planes.first;
      final expectedLength = image.width * image.height * 3 ~/ 2;
      if (plane.bytesPerRow != image.width ||
          plane.bytes.length < expectedLength) {
        return null;
      }
      return litert.CameraFrame(
        bytes: plane.bytes,
        width: image.width,
        height: image.height,
        strideCols: image.width,
        conversion: litert.CameraFrameConversion.yuv2bgrNv21,
        rotation: rotation,
      );
    }

    return litert.prepareCameraFrameFromImage(
      image,
      rotation: rotation,
      isBgra:
          _platform == TargetPlatform.iOS || _platform == TargetPlatform.macOS,
    );
  }

  litert.CameraFrameRotation? _cameraFrameRotation(int degrees) {
    return switch (degrees) {
      0 => null,
      90 => litert.CameraFrameRotation.cw90,
      180 => litert.CameraFrameRotation.cw180,
      270 => litert.CameraFrameRotation.cw270,
      _ => throw ArgumentError.value(degrees, 'degrees'),
    };
  }

  Future<face_tflite.FaceDetector> _ensureDetector() {
    final existing = _detector;
    if (existing != null) {
      return Future.value(existing);
    }
    final initialization = _detectorInitialization;
    if (initialization != null) {
      return initialization;
    }

    final future =
        face_tflite.FaceDetector.create(
          model: face_tflite.FaceDetectionModel.frontCamera,
          performanceConfig: const face_tflite.PerformanceConfig.auto(
            numThreads: 2,
          ),
          meshPoolSize: 1,
          minScore: 0.5,
          minFacePresenceConfidence: 0.5,
          enableTracking: true,
          maxMissedFrames: _maximumTrackedFaceMisses,
        ).then((detector) async {
          if (_closed) {
            await detector.dispose();
            throw StateError('Face detector was closed during initialization.');
          }
          _detector = detector;
          return detector;
        });
    _detectorInitialization = future;
    return future;
  }

  void _resetTrackingWhenCameraChanges(
    face_tflite.FaceDetector detector,
    String cameraName,
  ) {
    if (_cameraName == cameraName) {
      return;
    }
    _cameraName = cameraName;
    detector.resetTracking();
    _clearSelectedFace();
  }

  face_tflite.Face? _selectTrackedFace(List<face_tflite.Face> faces) {
    if (faces.isEmpty) {
      _selectedFaceMisses += 1;
      if (_selectedFaceMisses > _maximumTrackedFaceMisses) {
        _clearSelectedFace();
      }
      return null;
    }

    final selectedTrackingId = _selectedTrackingId;
    if (selectedTrackingId != null) {
      for (final face in faces) {
        if (face.trackingId == selectedTrackingId) {
          _selectedFaceMisses = 0;
          return face;
        }
      }
      _selectedFaceMisses += 1;
      if (_selectedFaceMisses <= _maximumTrackedFaceMisses) {
        return null;
      }
    }

    final selectedFace = _largestFace(faces);
    _selectedTrackingId = selectedFace?.trackingId;
    _selectedFaceMisses = 0;
    return selectedFace;
  }

  face_tflite.Face? _largestFace(List<face_tflite.Face> faces) {
    if (faces.isEmpty) {
      return null;
    }
    return faces.reduce((current, candidate) {
      final currentArea =
          current.boundingBox.width * current.boundingBox.height;
      final candidateArea =
          candidate.boundingBox.width * candidate.boundingBox.height;
      return candidateArea > currentArea ? candidate : current;
    });
  }

  StoryCardFaceObservation? _observationFromFace(face_tflite.Face face) {
    final mesh = face.mesh;
    if (mesh == null) {
      return null;
    }
    return StoryCardFaceMeshGeometry.fromPixelLandmarks(
      [for (final point in mesh.points) Offset(point.x, point.y)],
      Size(
        face.originalSize.width.toDouble(),
        face.originalSize.height.toDouble(),
      ),
    );
  }

  void _clearSelectedFace() {
    _selectedTrackingId = null;
    _selectedFaceMisses = 0;
  }

  Future<void> _disableMediaPipe(Object error, StackTrace stackTrace) async {
    if (kDebugMode && !_mediaPipeDisabled) {
      debugPrint('StoryCard MediaPipe disabled; using ML Kit: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    _mediaPipeDisabled = true;
    final detector = _detector;
    _detector = null;
    _detectorInitialization = null;
    _cameraName = null;
    _clearSelectedFace();
    await detector?.dispose();
  }
}

class _StoryCardFaceMeshDiagnostics {
  final List<int> _roundTripSamples = [];

  void record(int roundTripMicroseconds) {
    if (!kDebugMode) {
      return;
    }
    _roundTripSamples.add(roundTripMicroseconds);
    if (_roundTripSamples.length < 60) {
      return;
    }

    final sortedSamples = [..._roundTripSamples]..sort();
    final average =
        _roundTripSamples.reduce((a, b) => a + b) /
        _roundTripSamples.length /
        1000;
    final p95Index = (sortedSamples.length * 0.95).floor().clamp(
      0,
      sortedSamples.length - 1,
    );
    final p95 = sortedSamples[p95Index] / 1000;
    if (kDebugMode) {
      debugPrint(
        'StoryCard MediaPipe: frames=${_roundTripSamples.length}, '
        'roundTripAvg=${average.toStringAsFixed(1)}ms, '
        'roundTripP95=${p95.toStringAsFixed(1)}ms',
      );
    }
    _roundTripSamples.clear();
  }
}
