import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/story_card_camera_selection.dart';
import '../../application/story_card_editor_session.dart';
import '../../application/story_card_face_detector.dart';
import '../../application/story_card_face_detector_factory.dart';
import '../../application/story_card_face_effect.dart';
import '../../application/story_card_face_effect_capture.dart';
import '../../data/story_card_camera_effect.dart';
import '../../data/story_card_film_look.dart';
import '../../data/story_card_type.dart';
import 'story_card_camera_character_overlay.dart';
import 'story_card_camera_controller.dart';
import 'story_card_camera_face_tracker.dart';
import 'story_card_camera_focus_overlay.dart';
import 'story_card_camera_policy.dart';
import 'story_card_camera_style_selector.dart';
import 'story_card_editor_action_bar.dart';
import 'story_card_film_filtered_preview.dart';
import 'story_card_type_picker.dart';

class StoryCardCameraStage extends StatefulWidget {
  const StoryCardCameraStage({
    super.key,
    required this.onBack,
    required this.onImageSelected,
    required this.onTextSelected,
    required this.onDrawingSelected,
    this.initialFilm = const StoryCardFilmState.original(),
    this.onFilmChanged,
    this.initialCardType = StoryCardType.fullBleed,
    this.onCardTypeChanged,
    this.faceDetector,
    this.loadCharacterImage,
    this.showEditorTools = true,
    this.showGalleryButton = true,
    this.guideAspectRatio,
    this.draftCount = 0,
    this.onDraftsPressed,
  });

  final VoidCallback onBack;
  final ValueChanged<StoryCardCameraSelection> onImageSelected;
  final VoidCallback onTextSelected;
  final VoidCallback onDrawingSelected;
  final StoryCardFilmState initialFilm;
  final ValueChanged<StoryCardFilmState>? onFilmChanged;
  final StoryCardType initialCardType;
  final ValueChanged<StoryCardType>? onCardTypeChanged;
  final StoryCardFaceDetector? faceDetector;
  final Future<Uint8List?> Function()? loadCharacterImage;
  final bool showEditorTools;
  final bool showGalleryButton;
  final double? guideAspectRatio;
  final int draftCount;
  final VoidCallback? onDraftsPressed;

  @override
  State<StoryCardCameraStage> createState() => _StoryCardCameraStageState();
}

class _StoryCardCameraStageState extends State<StoryCardCameraStage>
    with WidgetsBindingObserver {
  final _imagePicker = ImagePicker();

  late final StoryCardCameraController _camera;
  Object? _captureError;
  bool _isCapturing = false;
  bool _isPickingImage = false;
  bool _isStyleSelectorVisible = false;
  bool _isCardTypeSelectorVisible = false;
  bool _isEffectLoading = false;
  late StoryCardFilmState _film;
  late StoryCardType _cardType;
  StoryCardCameraEffect _effect = StoryCardCameraEffect.none;
  StoryCardCharacterAsset? _character;
  StoryCardFaceObservation? _trackedFace;
  StoryCardFaceDetector? _faceDetector;
  StoryCardCameraFaceTracker? _faceTracker;
  StoryCardFilmLook? _announcedFilmLook;
  bool _isFilmAnnouncementVisible = false;
  Timer? _filmAnnouncementFadeTimer;
  Timer? _filmAnnouncementRemovalTimer;
  Offset? _focusPoint;
  double _exposureOffset = 0;
  Timer? _focusTimer;
  Offset _gestureDisplacement = Offset.zero;
  bool _gestureHadMultiplePointers = false;
  bool _isPinching = false;

  @override
  void initState() {
    super.initState();
    _film = widget.initialFilm.seed > 0
        ? widget.initialFilm
        : widget.initialFilm.copyWith(seed: StoryCardFilmSeed.now());
    _cardType = widget.initialCardType;
    _camera = StoryCardCameraController()..addListener(_handleCameraChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_camera.initialize());
  }

  @override
  void didUpdateWidget(covariant StoryCardCameraStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCardType != oldWidget.initialCardType &&
        widget.initialCardType != _cardType) {
      _cardType = widget.initialCardType;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _hideFocusOverlay();
      unawaited(_deactivateCamera());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_camera.initialize());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _filmAnnouncementFadeTimer?.cancel();
    _filmAnnouncementRemovalTimer?.cancel();
    _focusTimer?.cancel();
    _camera.removeListener(_handleCameraChanged);
    _effect = StoryCardCameraEffect.none;
    final faceTracker = _faceTracker;
    final faceDetector = _faceDetector;
    unawaited(
      _disposeCameraResources(tracker: faceTracker, detector: faceDetector),
    );
    super.dispose();
  }

  void _handleCameraChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      if (_camera.controller != null) {
        _captureError = null;
      } else {
        _focusPoint = null;
        _trackedFace = null;
      }
    });
    if (_camera.controller != null &&
        _effect == StoryCardCameraEffect.coupleCharacter) {
      unawaited(_startFaceTracking());
    }
  }

  Future<void> _switchCamera() async {
    if (_isCapturing || _isPickingImage) {
      return;
    }
    _hideFocusOverlay();
    await _stopFaceTracking();
    await _camera.switchCamera();
  }

  Future<void> _cycleFlash() async {
    if (_isCapturing || _isPickingImage) {
      return;
    }
    await _camera.cycleFlashMode();
  }

  void _toggleStyleSelector() {
    setState(() {
      _isStyleSelectorVisible = !_isStyleSelectorVisible;
      _isCardTypeSelectorVisible = false;
    });
  }

  void _toggleCardTypeSelector() {
    setState(() {
      _isCardTypeSelectorVisible = !_isCardTypeSelectorVisible;
      _isStyleSelectorVisible = false;
    });
  }

  void _selectCardType(StoryCardType type) {
    if (type == _cardType) {
      return;
    }
    setState(() => _cardType = type);
    widget.onCardTypeChanged?.call(type);
  }

  Future<void> _selectEffect(StoryCardCameraEffect effect) async {
    if (_isEffectLoading || effect == _effect) {
      return;
    }
    if (effect == StoryCardCameraEffect.none) {
      setState(() {
        _effect = effect;
        _trackedFace = null;
      });
      await _stopFaceTracking();
      return;
    }

    setState(() {
      _isEffectLoading = true;
    });
    try {
      var character = _character;
      if (character == null) {
        final bytes = await widget.loadCharacterImage?.call();
        if (bytes == null || bytes.isEmpty) {
          throw const _CharacterUnavailableException();
        }
        character = StoryCardCharacterAsset.fromBytes(bytes);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _character = character;
        _effect = effect;
        _isEffectLoading = false;
      });
      await _startFaceTracking();
    } on _CharacterUnavailableException {
      if (mounted) {
        setState(() {
          _isEffectLoading = false;
        });
        _showSnackBar('먼저 둘의 캐릭터를 만들어 주세요.');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isEffectLoading = false;
        });
        _showSnackBar('캐릭터 효과를 불러오지 못했어요.');
      }
    }
  }

  Future<void> _deactivateCamera() async {
    await _stopFaceTracking();
    await _camera.deactivate();
  }

  Future<void> _startFaceTracking() async {
    final controller = _camera.controller;
    if (!mounted ||
        _effect != StoryCardCameraEffect.coupleCharacter ||
        _character == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final detector = _obtainFaceDetector();
    final tracker = _faceTracker ??= StoryCardCameraFaceTracker(
      detector: detector,
      onFaceChanged: _handleTrackedFaceChanged,
    );
    await tracker.start(controller);
  }

  Future<void> _stopFaceTracking() async {
    await _faceTracker?.stop();
    if (mounted && _trackedFace != null) {
      setState(() {
        _trackedFace = null;
      });
    }
  }

  void _handleTrackedFaceChanged(StoryCardFaceObservation? face) {
    if (!mounted || _effect != StoryCardCameraEffect.coupleCharacter) {
      return;
    }
    setState(() {
      _trackedFace = face;
    });
  }

  StoryCardFaceDetector _obtainFaceDetector() {
    return _faceDetector ??=
        widget.faceDetector ?? StoryCardFaceDetectorFactory.create();
  }

  Future<void> _disposeCameraResources({
    required StoryCardCameraFaceTracker? tracker,
    required StoryCardFaceDetector? detector,
  }) async {
    try {
      await tracker?.dispose();
    } catch (error) {
      _logResourceDisposalFailure('tracker', error);
    }
    try {
      await detector?.close();
    } catch (error) {
      _logResourceDisposalFailure('detector', error);
    }
    _camera.dispose();
  }

  void _logResourceDisposalFailure(String resource, Object error) {
    if (kDebugMode) {
      debugPrint('Story card camera $resource disposal failed: $error');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectFilmLook(StoryCardFilmLook look) {
    final nextFilm = _film.copyWith(look: look);
    if (nextFilm == _film) {
      return;
    }
    setState(() {
      _film = nextFilm;
    });
    widget.onFilmChanged?.call(nextFilm);
  }

  void _stepFilm(int delta) {
    final looks = StoryCardFilmLook.values;
    final currentIndex = looks.indexOf(_film.look);
    final nextIndex = (currentIndex + delta) % looks.length;
    final nextLook = looks[nextIndex];
    _selectFilmLook(nextLook);
    _announceFilmLook(nextLook);
  }

  void _announceFilmLook(StoryCardFilmLook look) {
    _filmAnnouncementFadeTimer?.cancel();
    _filmAnnouncementRemovalTimer?.cancel();
    setState(() {
      _announcedFilmLook = look;
      _isFilmAnnouncementVisible = true;
    });
    _filmAnnouncementFadeTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFilmAnnouncementVisible = false;
      });
    });
    _filmAnnouncementRemovalTimer = Timer(
      const Duration(milliseconds: 950),
      () {
        if (!mounted) {
          return;
        }
        setState(() {
          _announcedFilmLook = null;
        });
      },
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _gestureDisplacement = Offset.zero;
    _gestureHadMultiplePointers = details.pointerCount > 1;
    _isPinching = details.pointerCount > 1;
    if (_isPinching) {
      _camera.beginScale();
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount > 1) {
      _gestureHadMultiplePointers = true;
      if (!_isPinching) {
        _isPinching = true;
        _camera.beginScale();
      }
      _camera.updateScale(details.scale);
      return;
    }
    if (!_gestureHadMultiplePointers) {
      _gestureDisplacement += details.focalPointDelta;
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    final action = StoryCardCameraPolicy.classifySwipe(
      displacement: _gestureDisplacement,
      velocity: details.velocity.pixelsPerSecond,
      pointerCount: _gestureHadMultiplePointers ? 2 : 1,
    );
    _gestureDisplacement = Offset.zero;
    _gestureHadMultiplePointers = false;
    _isPinching = false;

    switch (action) {
      case StoryCardCameraSwipeAction.none:
        return;
      case StoryCardCameraSwipeAction.nextFilm:
        _stepFilm(1);
        return;
      case StoryCardCameraSwipeAction.previousFilm:
        _stepFilm(-1);
        return;
      case StoryCardCameraSwipeAction.switchCamera:
        unawaited(_switchCamera());
        return;
    }
  }

  void _handlePreviewTap(TapUpDetails details, Size viewport) {
    final controller = _camera.controller;
    if (controller == null ||
        (!controller.value.focusPointSupported &&
            !controller.value.exposurePointSupported) ||
        viewport.isEmpty) {
      return;
    }

    final normalizedPoint = Offset(
      (details.localPosition.dx / viewport.width).clamp(0.0, 1.0).toDouble(),
      (details.localPosition.dy / viewport.height).clamp(0.0, 1.0).toDouble(),
    );
    setState(() {
      _focusPoint = normalizedPoint;
      _exposureOffset = _camera.exposureOffset;
    });
    _restartFocusTimer();
    unawaited(_camera.setFocusAndExposurePoint(normalizedPoint));
  }

  void _handleExposureChanged(double offset) {
    setState(() {
      _exposureOffset = offset;
    });
    _camera.setExposureOffset(offset);
    _restartFocusTimer();
  }

  void _handleExposureChangeStarted() {
    _focusTimer?.cancel();
  }

  void _restartFocusTimer() {
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(seconds: 3), _hideFocusOverlay);
  }

  void _hideFocusOverlay() {
    _focusTimer?.cancel();
    _focusTimer = null;
    if (!mounted || _focusPoint == null) {
      return;
    }
    setState(() {
      _focusPoint = null;
    });
  }

  Future<void> _capturePhoto() async {
    final controller = _camera.controller;
    if (_isCapturing ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });
    try {
      final characterSide = _trackedFace?.characterSide;
      await _stopFaceTracking();
      final image = await controller.takePicture();
      widget.onImageSelected(
        await _prepareSelection(image, characterSide: characterSide),
      );
    } on StoryCardFaceNotFoundException {
      if (mounted) {
        _showSnackBar('얼굴을 찾지 못했어요. 얼굴이 보이게 다시 찍어 주세요.');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _captureError = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        if (_effect == StoryCardCameraEffect.coupleCharacter) {
          unawaited(_startFaceTracking());
        }
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isPickingImage || _isCapturing) {
      return;
    }

    setState(() {
      _isPickingImage = true;
    });
    try {
      await _stopFaceTracking();
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (image != null) {
        widget.onImageSelected(await _prepareSelection(image));
      }
    } on StoryCardFaceNotFoundException {
      if (mounted) {
        _showSnackBar('사진에서 얼굴을 찾지 못했어요.');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('사진을 불러오지 못했어요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
        if (_effect == StoryCardCameraEffect.coupleCharacter) {
          unawaited(_startFaceTracking());
        }
      }
    }
  }

  Future<StoryCardCameraSelection> _prepareSelection(
    XFile image, {
    StoryCardCharacterSide? characterSide,
  }) async {
    final imageBytes = await image.readAsBytes();
    StoryCardCharacterComposition? composition;
    if (_effect == StoryCardCameraEffect.coupleCharacter) {
      final character = _character;
      if (character == null) {
        throw const _CharacterUnavailableException();
      }
      final detector = _obtainFaceDetector();
      composition = await StoryCardFaceEffectCapture(detector: detector)
          .detectComposition(
            imagePath: image.path,
            imageBytes: imageBytes,
            character: character,
            characterSide: characterSide,
          );
    }

    return StoryCardCameraSelection(
      imageBytes: imageBytes,
      film: _film,
      cardType: _cardType,
      characterComposition: composition,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _camera.controller;
    final guideAspectRatio =
        widget.guideAspectRatio ??
        (widget.showEditorTools
            ? StoryCardLayout.fromSize(
                type: _cardType,
                size: _cardType.previewSize,
              ).photoAspectRatio(0)
            : null);
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            _CoveringCameraPreview(
              controller: controller,
              film: _film,
              character: _character,
              trackedFace: _trackedFace,
              onPointerDown: (_) => _camera.addPointer(),
              onPointerUp: (_) => _camera.removePointer(),
              onPointerCancel: (_) => _camera.removePointer(),
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              onScaleEnd: _handleScaleEnd,
              onTapUp: _handlePreviewTap,
            )
          else
            _CameraUnavailable(error: _captureError ?? _camera.error),
          if (guideAspectRatio case final aspectRatio?)
            _StoryCardCameraCropGuide(aspectRatio: aspectRatio),
          if (_focusPoint case final focusPoint?)
            StoryCardCameraFocusOverlay(
              normalizedPoint: focusPoint,
              exposureOffset: _exposureOffset,
              minimumExposureOffset: _camera.minimumExposureOffset,
              maximumExposureOffset: _camera.maximumExposureOffset,
              onExposureChanged: _handleExposureChanged,
              onExposureChangeStarted: _handleExposureChangeStarted,
              onExposureChangeEnded: _restartFocusTimer,
            ),
          SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('story-card-camera-close'),
                        tooltip: '나가기',
                        onPressed: widget.onBack,
                        color: Colors.white,
                        icon: const Icon(Icons.close, size: 30),
                      ),
                      if (widget.onDraftsPressed case final onPressed?)
                        _CameraDraftsButton(
                          count: widget.draftCount,
                          onPressed: onPressed,
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    key: const ValueKey('story-card-camera-flash'),
                    tooltip: _flashTooltip(_camera.flashMode),
                    onPressed: _camera.canChangeFlash ? _cycleFlash : null,
                    color: Colors.white,
                    disabledColor: const Color(0x66FFFFFF),
                    icon: Icon(_flashIcon(_camera.flashMode), size: 28),
                  ),
                ),
                if (widget.showEditorTools)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: StoryCardEditorActionBar(
                        interactionMode: StoryCardEditorTool.none,
                        hasBackground: true,
                        cardType: _cardType,
                        onAddTextPressed: widget.onTextSelected,
                        onDrawingModePressed: widget.onDrawingSelected,
                        onBackgroundColorPressed: null,
                        onFilmPressed: _toggleStyleSelector,
                        onCardTypePressed: _toggleCardTypeSelector,
                        isFilmSelected:
                            _isStyleSelectorVisible ||
                            _film.look != StoryCardFilmLook.original ||
                            _effect != StoryCardCameraEffect.none,
                        isCardTypeSelected: _isCardTypeSelectorVisible,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _CameraBottomControls(
                    canCapture:
                        controller != null &&
                        controller.value.isInitialized &&
                        !_isCapturing,
                    isCapturing: _isCapturing,
                    isPickingImage: _isPickingImage,
                    canSwitchCamera:
                        _camera.alternateCamera != null || _camera.isSwitching,
                    isSwitchingCamera: _camera.isSwitching,
                    onGalleryPressed: widget.showGalleryButton
                        ? _pickFromGallery
                        : null,
                    onCapturePressed: _capturePhoto,
                    onSwitchCameraPressed: _switchCamera,
                  ),
                ),
                if (widget.showEditorTools && _isStyleSelectorVisible)
                  Positioned(
                    key: const ValueKey('story-card-camera-film-selector'),
                    left: 12,
                    right: 12,
                    bottom: 128,
                    child: StoryCardCameraStyleSelector(
                      selectedFilmLook: _film.look,
                      selectedEffect: _effect,
                      isEffectLoading: _isEffectLoading,
                      onFilmLookChanged: _selectFilmLook,
                      onEffectChanged: (effect) =>
                          unawaited(_selectEffect(effect)),
                    ),
                  ),
                if (widget.showEditorTools && _isCardTypeSelectorVisible)
                  Positioned(
                    key: const ValueKey('story-card-camera-type-selector'),
                    left: 12,
                    right: 12,
                    bottom: 128,
                    child: StoryCardTypePicker(
                      selectedType: _cardType,
                      onSelected: _selectCardType,
                      keyPrefix: 'story-card-camera-type',
                    ),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  opacity: _isFilmAnnouncementVisible ? 1 : 0,
                  child: _announcedFilmLook == null
                      ? const SizedBox.shrink()
                      : _FilmLookAnnouncement(look: _announcedFilmLook!),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraDraftsButton extends StatelessWidget {
  const _CameraDraftsButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const ValueKey('story-card-camera-drafts'),
          tooltip: '임시 저장 카드',
          onPressed: onPressed,
          color: Colors.white,
          icon: const Icon(LucideIcons.archive, size: 27),
        ),
        if (count > 0)
          Positioned(
            right: 1,
            top: 1,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFE46F61),
                  shape: BoxShape.circle,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StoryCardCameraCropGuide extends StatelessWidget {
  const _StoryCardCameraCropGuide({required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final maxWidth = size.width * 0.86;
            final maxHeight = size.height * 0.58;
            final width = math.min(maxWidth, maxHeight * aspectRatio);
            final height = width / aspectRatio;
            final frame = Rect.fromCenter(
              center: size.center(Offset.zero),
              width: width,
              height: height,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CameraCropMaskPainter(frame: frame),
                  ),
                ),
                Positioned.fromRect(
                  rect: frame,
                  child: SizedBox(
                    key: const ValueKey('story-card-camera-crop-guide'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CameraCropMaskPainter extends CustomPainter {
  const _CameraCropMaskPainter({required this.frame});

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final frameShape = RRect.fromRectAndRadius(frame, const Radius.circular(2));
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frameShape);
    canvas.drawPath(mask, Paint()..color = const Color(0x66000000));
    canvas.drawRRect(
      frameShape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xE6FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _CameraCropMaskPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}

class _CameraBottomControls extends StatelessWidget {
  const _CameraBottomControls({
    required this.canCapture,
    required this.isCapturing,
    required this.isPickingImage,
    required this.canSwitchCamera,
    required this.isSwitchingCamera,
    required this.onGalleryPressed,
    required this.onCapturePressed,
    required this.onSwitchCameraPressed,
  });

  final bool canCapture;
  final bool isCapturing;
  final bool isPickingImage;
  final bool canSwitchCamera;
  final bool isSwitchingCamera;
  final VoidCallback? onGalleryPressed;
  final VoidCallback onCapturePressed;
  final VoidCallback onSwitchCameraPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      child: SizedBox(
        height: 108,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: onGalleryPressed == null
                    ? const SizedBox.square(dimension: 54)
                    : _CameraAuxiliaryButton(
                        key: const ValueKey('story-card-camera-gallery'),
                        tooltip: '갤러리',
                        onPressed: isPickingImage ? null : onGalleryPressed,
                        child: isPickingImage
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                LucideIcons.image,
                                color: Colors.white,
                                size: 27,
                              ),
                      ),
              ),
            ),
            _CaptureButton(
              isEnabled: canCapture,
              isCapturing: isCapturing,
              onPressed: onCapturePressed,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: canSwitchCamera
                    ? _CameraAuxiliaryButton(
                        key: const ValueKey('story-card-camera-switch'),
                        tooltip: '카메라 전환',
                        onPressed:
                            isSwitchingCamera || isCapturing || isPickingImage
                            ? null
                            : onSwitchCameraPressed,
                        child: isSwitchingCamera
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                LucideIcons.refreshCcw,
                                color: Colors.white,
                                size: 29,
                              ),
                      )
                    : const SizedBox.square(dimension: 54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraAuxiliaryButton extends StatelessWidget {
  const _CameraAuxiliaryButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: isEnabled,
        label: tooltip,
        child: SizedBox.square(
          dimension: 54,
          child: Material(
            color: isEnabled
                ? const Color(0x52000000)
                : const Color(0x26000000),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: AnimatedOpacity(
                  opacity: isEnabled ? 1 : 0.45,
                  duration: const Duration(milliseconds: 160),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoveringCameraPreview extends StatelessWidget {
  const _CoveringCameraPreview({
    required this.controller,
    required this.film,
    required this.character,
    required this.trackedFace,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onTapUp,
  });

  final CameraController controller;
  final StoryCardFilmState film;
  final StoryCardCharacterAsset? character;
  final StoryCardFaceObservation? trackedFace;
  final PointerDownEventListener onPointerDown;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleEndCallback onScaleEnd;
  final void Function(TapUpDetails details, Size viewport) onTapUp;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const SizedBox.expand();
    }

    return Listener(
      key: const ValueKey('story-card-camera-preview'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: onPointerDown,
      onPointerUp: onPointerUp,
      onPointerCancel: onPointerCancel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => onTapUp(details, constraints.biggest),
            onScaleStart: onScaleStart,
            onScaleUpdate: onScaleUpdate,
            onScaleEnd: onScaleEnd,
            child: ClipRect(
              child: StoryCardFilmFilteredPreview(
                film: film,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: previewSize.height,
                    height: previewSize.width,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(controller),
                        if (character case final character?)
                          if (trackedFace case final trackedFace?)
                            StoryCardCameraCharacterOverlay(
                              face: trackedFace,
                              character: character,
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilmLookAnnouncement extends StatelessWidget {
  const _FilmLookAnnouncement({required this.look});

  final StoryCardFilmLook look;

  @override
  Widget build(BuildContext context) {
    return Text(
      look.label,
      key: const ValueKey('story-card-camera-film-announcement'),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(color: Color(0xB3000000), blurRadius: 8),
          Shadow(color: Color(0x66000000), blurRadius: 2),
        ],
      ),
    );
  }
}

IconData _flashIcon(FlashMode mode) {
  return switch (mode) {
    FlashMode.off => Icons.flash_off_rounded,
    FlashMode.auto => Icons.flash_auto_rounded,
    FlashMode.always => Icons.flash_on_rounded,
    FlashMode.torch => Icons.flashlight_on_rounded,
  };
}

String _flashTooltip(FlashMode mode) {
  return switch (mode) {
    FlashMode.off => '플래시 끔',
    FlashMode.auto => '플래시 자동',
    FlashMode.always => '플래시 켬',
    FlashMode.torch => '플래시 조명',
  };
}

class _CaptureButton extends StatefulWidget {
  const _CaptureButton({
    required this.isEnabled,
    required this.isCapturing,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isCapturing;
  final VoidCallback onPressed;

  @override
  State<_CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<_CaptureButton> {
  var _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value || !mounted) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.isEnabled && !widget.isCapturing;
    return Tooltip(
      message: '촬영',
      child: Semantics(
        button: true,
        enabled: isEnabled,
        label: '촬영',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isEnabled ? widget.onPressed : null,
          onTapDown: isEnabled ? (_) => _setPressed(true) : null,
          onTapUp: isEnabled ? (_) => _setPressed(false) : null,
          onTapCancel: isEnabled ? () => _setPressed(false) : null,
          child: SizedBox.square(
            key: const ValueKey('story-card-camera-capture'),
            dimension: 80,
            child: Center(
              child: AnimatedScale(
                scale: _isPressed ? 0.94 : 1,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: widget.isEnabled ? 1 : 0.45,
                  duration: const Duration(milliseconds: 160),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x59000000), blurRadius: 8),
                      ],
                    ),
                    child: SizedBox.square(
                      dimension: 76,
                      child: widget.isCapturing
                          ? const Center(
                              child: SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  color: Color(0xB3000000),
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          error == null
              ? '카메라를 준비하고 있어요.'
              : '카메라를 사용할 수 없어요.\n갤러리, 텍스트 또는 그리기로 시작해 주세요.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _CharacterUnavailableException implements Exception {
  const _CharacterUnavailableException();
}
