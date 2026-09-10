import 'dart:async';
import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'story_card_camera_policy.dart';

class StoryCardCameraController extends ChangeNotifier {
  static const _platformControlInterval = Duration(milliseconds: 32);

  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  String? _selectedCameraName;
  Object? _error;
  bool _isSwitching = false;
  bool _isChangingFlash = false;
  bool _isFlashSupported = false;
  FlashMode _flashMode = FlashMode.off;
  bool _isDisposed = false;
  int _generation = 0;
  int _pointerCount = 0;
  double _minimumZoom = 1;
  double _maximumZoom = 1;
  double _currentZoom = 1;
  double _baseZoom = 1;
  double? _pendingZoom;
  bool _isApplyingZoom = false;
  Timer? _zoomDispatchTimer;
  double _minimumExposureOffset = 0;
  double _maximumExposureOffset = 0;
  double _exposureOffset = 0;
  bool _isExposureSupported = false;
  double? _pendingExposureOffset;
  bool _isApplyingExposure = false;
  Timer? _exposureDispatchTimer;

  CameraController? get controller => _controller;
  Object? get error => _error;
  bool get isSwitching => _isSwitching;
  bool get isChangingFlash => _isChangingFlash;
  bool get isFlashSupported => _isFlashSupported;
  FlashMode get flashMode => _flashMode;
  double get minimumExposureOffset => _minimumExposureOffset;
  double get maximumExposureOffset => _maximumExposureOffset;
  double get exposureOffset => _exposureOffset;

  bool get canAdjustExposure {
    final currentController = _controller;
    return currentController != null &&
        currentController.value.isInitialized &&
        _isExposureSupported;
  }

  bool get canChangeFlash {
    final currentController = _controller;
    return currentController != null &&
        currentController.value.isInitialized &&
        _isFlashSupported &&
        !_isChangingFlash;
  }

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
    _cancelDeferredControls();
    _controller = null;
    _pendingZoom = null;
    _pendingExposureOffset = null;
    _pointerCount = 0;
    _error = null;
    _isSwitching = isSwitching;
    _isChangingFlash = false;
    _isFlashSupported = false;
    _flashMode = FlashMode.off;
    _minimumExposureOffset = 0;
    _maximumExposureOffset = 0;
    _exposureOffset = 0;
    _isExposureSupported = false;
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
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await nextController.initialize();
      if (!_isCurrentGeneration(generation)) {
        await _disposeController(nextController);
        return;
      }

      final flashSupported = await _initializeFlash(nextController);
      if (!_isCurrentGeneration(generation)) {
        await _disposeController(nextController);
        return;
      }

      final zoomBounds = await Future.wait([
        nextController.getMinZoomLevel(),
        nextController.getMaxZoomLevel(),
      ]);
      final exposureRange = await _readExposureRange(nextController);
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
      _isFlashSupported = flashSupported;
      _flashMode = FlashMode.off;
      _minimumZoom = minimumZoom;
      _maximumZoom = maximumZoom;
      _currentZoom = initialZoom;
      _baseZoom = initialZoom;
      _minimumExposureOffset = exposureRange.minimum;
      _maximumExposureOffset = exposureRange.maximum;
      _exposureOffset = 0
          .clamp(exposureRange.minimum, exposureRange.maximum)
          .toDouble();
      _isExposureSupported = exposureRange.isSupported;
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
    _cancelDeferredControls();
    _controller = null;
    _pendingZoom = null;
    _pendingExposureOffset = null;
    _pointerCount = 0;
    _isSwitching = false;
    _isChangingFlash = false;
    _isFlashSupported = false;
    _flashMode = FlashMode.off;
    _minimumExposureOffset = 0;
    _maximumExposureOffset = 0;
    _exposureOffset = 0;
    _isExposureSupported = false;
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

  Future<bool> cycleFlashMode() async {
    final currentController = _controller;
    if (!canChangeFlash || currentController == null) {
      return false;
    }

    final nextMode = StoryCardCameraPolicy.nextFlashMode(_flashMode);
    _isChangingFlash = true;
    notifyListeners();
    try {
      await currentController.setFlashMode(nextMode);
      if (_controller != currentController || _isDisposed) {
        return false;
      }
      _flashMode = nextMode;
      return true;
    } catch (error) {
      _isFlashSupported = false;
      if (kDebugMode) {
        debugPrint('Failed to change story card camera flash: $error');
      }
      return false;
    } finally {
      if (_controller == currentController && !_isDisposed) {
        _isChangingFlash = false;
        notifyListeners();
      }
    }
  }

  Future<bool> setFocusAndExposurePoint(Offset normalizedPoint) async {
    final currentController = _controller;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        _isDisposed) {
      return false;
    }

    final point = Offset(
      normalizedPoint.dx.clamp(0.0, 1.0).toDouble(),
      normalizedPoint.dy.clamp(0.0, 1.0).toDouble(),
    );
    var didApply = false;
    if (currentController.value.exposurePointSupported) {
      try {
        await currentController.setExposurePoint(point);
        didApply = true;
      } catch (error) {
        _logControlFailure('exposure point', error);
      }
    }
    if (currentController.value.focusPointSupported) {
      try {
        await currentController.setFocusPoint(point);
        didApply = true;
      } catch (error) {
        _logControlFailure('focus point', error);
      }
    }
    return didApply;
  }

  void setExposureOffset(double offset) {
    final currentController = _controller;
    if (!canAdjustExposure || currentController == null || !offset.isFinite) {
      return;
    }

    final nextOffset = offset
        .clamp(_minimumExposureOffset, _maximumExposureOffset)
        .toDouble();
    _exposureOffset = nextOffset;
    _pendingExposureOffset = nextOffset;
    _scheduleExposureUpdate();
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
    _scheduleZoomUpdate();
  }

  void _scheduleZoomUpdate() {
    if (_isDisposed ||
        _controller == null ||
        _pendingZoom == null ||
        _isApplyingZoom ||
        _zoomDispatchTimer != null) {
      return;
    }
    unawaited(_applyPendingZoom());
  }

  Future<void> _applyPendingZoom() async {
    final currentController = _controller;
    final zoom = _pendingZoom;
    if (_isApplyingZoom || currentController == null || zoom == null) {
      return;
    }

    _pendingZoom = null;
    _isApplyingZoom = true;
    try {
      await currentController.setZoomLevel(zoom);
    } catch (error) {
      _logControlFailure('zoom', error);
    } finally {
      _isApplyingZoom = false;
      if (!_isDisposed && _controller != null) {
        if (_controller != currentController) {
          _scheduleZoomUpdate();
        } else {
          _zoomDispatchTimer = Timer(_platformControlInterval, () {
            _zoomDispatchTimer = null;
            _scheduleZoomUpdate();
          });
        }
      }
    }
  }

  void _scheduleExposureUpdate() {
    if (_isDisposed ||
        _controller == null ||
        _pendingExposureOffset == null ||
        _isApplyingExposure ||
        _exposureDispatchTimer != null) {
      return;
    }
    unawaited(_applyPendingExposure());
  }

  Future<void> _applyPendingExposure() async {
    final currentController = _controller;
    final offset = _pendingExposureOffset;
    if (_isApplyingExposure || currentController == null || offset == null) {
      return;
    }

    _pendingExposureOffset = null;
    _isApplyingExposure = true;
    try {
      final appliedOffset = await currentController.setExposureOffset(offset);
      if (_controller == currentController && _pendingExposureOffset == null) {
        _exposureOffset = appliedOffset;
      }
    } catch (error) {
      _logControlFailure('exposure offset', error);
    } finally {
      _isApplyingExposure = false;
      if (!_isDisposed && _controller != null) {
        if (_controller != currentController) {
          _scheduleExposureUpdate();
        } else {
          _exposureDispatchTimer = Timer(_platformControlInterval, () {
            _exposureDispatchTimer = null;
            _scheduleExposureUpdate();
          });
        }
      }
    }
  }

  bool _isCurrentGeneration(int generation) {
    return !_isDisposed && generation == _generation;
  }

  Future<bool> _initializeFlash(CameraController controller) async {
    try {
      await controller.setFlashMode(FlashMode.off);
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Story card camera flash is unavailable: $error');
      }
      return false;
    }
  }

  Future<_ExposureRange> _readExposureRange(CameraController controller) async {
    try {
      final range = await Future.wait([
        controller.getMinExposureOffset(),
        controller.getMaxExposureOffset(),
      ]);
      final minimum = range[0];
      final maximum = range[1];
      if (!minimum.isFinite || !maximum.isFinite || minimum >= maximum) {
        return const _ExposureRange.unsupported();
      }
      return _ExposureRange(minimum: minimum, maximum: maximum);
    } catch (error) {
      _logControlFailure('exposure range', error);
      return const _ExposureRange.unsupported();
    }
  }

  void _cancelDeferredControls() {
    _zoomDispatchTimer?.cancel();
    _zoomDispatchTimer = null;
    _exposureDispatchTimer?.cancel();
    _exposureDispatchTimer = null;
  }

  void _logControlFailure(String control, Object error) {
    if (kDebugMode) {
      debugPrint('Story card camera $control is unavailable: $error');
    }
  }

  Future<void> _disposeController(CameraController? controller) async {
    try {
      await controller?.dispose();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to dispose story card camera: $error');
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _generation += 1;
    _cancelDeferredControls();
    _pendingZoom = null;
    _pendingExposureOffset = null;
    unawaited(_disposeController(_controller));
    _controller = null;
    super.dispose();
  }
}

class _ExposureRange {
  const _ExposureRange({required this.minimum, required this.maximum})
    : isSupported = true;

  const _ExposureRange.unsupported()
    : minimum = 0,
      maximum = 0,
      isSupported = false;

  final double minimum;
  final double maximum;
  final bool isSupported;
}
