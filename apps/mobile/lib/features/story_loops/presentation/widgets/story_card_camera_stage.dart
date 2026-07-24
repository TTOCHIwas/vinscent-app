import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/story_card_editor_session.dart';
import 'story_card_camera_controller.dart';
import 'story_card_editor_action_bar.dart';

class StoryCardCameraStage extends StatefulWidget {
  const StoryCardCameraStage({
    super.key,
    required this.onBack,
    required this.onImageSelected,
    required this.onTextSelected,
    required this.onDrawingSelected,
  });

  final VoidCallback onBack;
  final ValueChanged<Uint8List> onImageSelected;
  final VoidCallback onTextSelected;
  final VoidCallback onDrawingSelected;

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

  @override
  void initState() {
    super.initState();
    _camera = StoryCardCameraController()..addListener(_handleCameraChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_camera.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      unawaited(_camera.deactivate());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_camera.initialize());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.removeListener(_handleCameraChanged);
    _camera.dispose();
    super.dispose();
  }

  void _handleCameraChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      if (_camera.controller != null) {
        _captureError = null;
      }
    });
  }

  Future<void> _switchCamera() async {
    if (_isCapturing || _isPickingImage) {
      return;
    }
    await _camera.switchCamera();
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
      final image = await controller.takePicture();
      widget.onImageSelected(await image.readAsBytes());
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
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (image != null) {
        widget.onImageSelected(await image.readAsBytes());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _camera.controller;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            _CoveringCameraPreview(
              controller: controller,
              onPointerDown: (_) => _camera.addPointer(),
              onPointerUp: (_) => _camera.removePointer(),
              onPointerCancel: (_) => _camera.removePointer(),
              onScaleStart: (_) => _camera.beginScale(),
              onScaleUpdate: (details) => _camera.updateScale(details.scale),
            )
          else
            _CameraUnavailable(error: _captureError ?? _camera.error),
          SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    tooltip: '나가기',
                    onPressed: widget.onBack,
                    color: Colors.white,
                    icon: const Icon(Icons.close, size: 30),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: StoryCardEditorActionBar(
                      interactionMode: StoryCardEditorTool.none,
                      hasBackground: true,
                      onAddTextPressed: widget.onTextSelected,
                      onEditCaptionPressed: null,
                      onDrawingModePressed: widget.onDrawingSelected,
                      onBackgroundColorPressed: null,
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
                    onGalleryPressed: _pickFromGallery,
                    onCapturePressed: _capturePhoto,
                    onSwitchCameraPressed: _switchCamera,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
  final VoidCallback onGalleryPressed;
  final VoidCallback onCapturePressed;
  final VoidCallback onSwitchCameraPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: SizedBox(
        height: 88,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton.filledTonal(
                  tooltip: '갤러리',
                  onPressed: isPickingImage ? null : onGalleryPressed,
                  icon: const Icon(Icons.photo_library_outlined),
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
                    ? IconButton.filledTonal(
                        key: const ValueKey('story-card-camera-switch'),
                        tooltip: '카메라 전환',
                        onPressed:
                            isSwitchingCamera || isCapturing || isPickingImage
                            ? null
                            : onSwitchCameraPressed,
                        icon: isSwitchingCamera
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cameraswitch_outlined),
                      )
                    : const SizedBox.square(dimension: 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoveringCameraPreview extends StatelessWidget {
  const _CoveringCameraPreview({
    required this.controller,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final CameraController controller;
  final PointerDownEventListener onPointerDown;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewSize.height,
              height: previewSize.width,
              child: CameraPreview(controller),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.isEnabled,
    required this.isCapturing,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isCapturing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '촬영',
      onPressed: isEnabled ? onPressed : null,
      iconSize: 72,
      color: Colors.white,
      icon: isCapturing
          ? const SizedBox.square(
              dimension: 30,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : const Icon(Icons.radio_button_unchecked),
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
