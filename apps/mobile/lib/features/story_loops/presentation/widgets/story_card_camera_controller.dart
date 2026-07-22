import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'story_card_camera_policy.dart';

class StoryCardCameraController extends ChangeNotifier {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  String? _selectedCameraName;
  Object? _error;
  bool _isSwitching = false;
  bool _isDisposed = false;
  int _generation = 0;
  int _pointerCount = 0;
  double _minimumZoom = 1;
  double _maximumZoom = 1;
  double _currentZoom = 1;
  double _baseZoom = 1;
  double? _pendingZoom;
  bool _isApplyingZoom = false;

  CameraController? get controller => _controller;
  Object? get error => _error;
  bool get isSwitching => _isSwitching;

  CameraDescription? get alternateCamera {
    final currentController = _controller;
    if (currentController == null) {
      return null;
    }
    return StoryCardCameraPolicy.alternate(
      cameras: _cameras,
      current: currentController.description,
    );
  }

  Future<void> initialize({
    String? preferredCameraName,
    bool isSwitching = false,
  }) async {
    final generation = ++_generation;
    final previousController = _controller;
    _controller = null;
    _pendingZoom = null;
    _pointerCount = 0;
    _error = null;
    _isSwitching = isSwitching;
    if (!_isDisposed && (previousController != null || isSwitching)) {
      notifyListeners();
    }
    await _disposeController(previousController);

    CameraController? nextController;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('camera_unavailable', 'No camera found.');
      }
      if (!_isCurrentGeneration(generation)) {
        return;
      }

      final description = StoryCardCameraPolicy.select(
        cameras,
        preferredCameraName: preferredCameraName ?? _selectedCameraName,
      );
      nextController = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await nextController.initialize();
      if (!_isCurrentGeneration(generation)) {
        await _disposeController(nextController);
        return;
      }

      final zoomBounds = await Future.wait([
        nextController.getMinZoomLevel(),
        nextController.getMaxZoomLevel(),
      ]);
      if (!_isCurrentGeneration(generation)) {
        await _disposeController(nextController);
        return;
      }

      final minimumZoom = zoomBounds[0];
      final maximumZoom = zoomBounds[1];
      final initialZoom = StoryCardCameraPolicy.initialZoom(
        minimum: minimumZoom,
        maximum: maximumZoom,
      );
      if (initialZoom != 1) {
        await nextController.setZoomLevel(initialZoom);
      }
      if (!_isCurrentGeneration(generation)) {
        await _disposeController(nextController);
        return;
      }

      _cameras = List.unmodifiable(cameras);
      _controller = nextController;
      _selectedCameraName = description.name;
      _error = null;
      _isSwitching = false;
      _minimumZoom = minimumZoom;
      _maximumZoom = maximumZoom;
      _currentZoom = initialZoom;
      _baseZoom = initialZoom;
      notifyListeners();
    } catch (error) {
      await _disposeController(nextController);
      if (_isCurrentGeneration(generation)) {
        _error = error;
        _isSwitching = false;
        notifyListeners();
      }
    }
  }

  Future<void> deactivate() async {
    _generation += 1;
    final currentController = _controller;
    _controller = null;
    _pendingZoom = null;
    _pointerCount = 0;
    _isSwitching = false;
    if (!_isDisposed && currentController != null) {
      notifyListeners();
    }
    await _disposeController(currentController);
  }

  Future<void> switchCamera() async {
    if (_isSwitching) {
      return;
    }
    final nextCamera = alternateCamera;
    if (nextCamera == null) {
      return;
    }

    await initialize(preferredCameraName: nextCamera.name, isSwitching: true);
  }

  void addPointer() {
    _pointerCount += 1;
  }

  void removePointer() {
    if (_pointerCount > 0) {
      _pointerCount -= 1;
    }
  }

  void beginScale() {
    if (_pointerCount == 2) {
      _baseZoom = _currentZoom;
    }
  }

  void updateScale(double gestureScale) {
    final currentController = _controller;
    if (_pointerCount != 2 ||
        currentController == null ||
        !currentController.value.isInitialized) {
      return;
    }

    final zoom = StoryCardCameraPolicy.scaledZoom(
      baseZoom: _baseZoom,
      gestureScale: gestureScale,
      minimum: _minimumZoom,
      maximum: _maximumZoom,
    );
    if ((zoom - _currentZoom).abs() < 0.01) {
      return;
    }

    _currentZoom = zoom;
    _pendingZoom = zoom;
    unawaited(_applyPendingZoom());
  }

  Future<void> _applyPendingZoom() async {
    if (_isApplyingZoom) {
      return;
    }

    _isApplyingZoom = true;
    try {
      while (!_isDisposed) {
        final currentController = _controller;
        final zoom = _pendingZoom;
        if (currentController == null || zoom == null) {
          return;
        }

        _pendingZoom = null;
        try {
          await currentController.setZoomLevel(zoom);
        } on CameraException {
          return;
        }
      }
    } finally {
      _isApplyingZoom = false;
      if (!_isDisposed && _controller != null && _pendingZoom != null) {
        unawaited(_applyPendingZoom());
      }
    }
  }

  bool _isCurrentGeneration(int generation) {
    return !_isDisposed && generation == _generation;
  }

  Future<void> _disposeController(CameraController? controller) async {
    try {
      await controller?.dispose();
    } catch (error) {
      debugPrint('Failed to dispose story card camera: $error');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _generation += 1;
    unawaited(_disposeController(_controller));
    _controller = null;
    super.dispose();
  }
}
