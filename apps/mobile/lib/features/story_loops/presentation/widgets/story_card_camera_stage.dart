import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  CameraController? _cameraController;
  Object? _cameraError;
  bool _isCapturing = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    await _disposeCamera();

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('camera_unavailable', 'No camera found.');
      }

      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _cameraError = error;
        });
      }
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    await controller?.dispose();
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
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
          _cameraError = error;
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
    final controller = _cameraController;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            _CoveringCameraPreview(controller: controller)
          else
            _CameraUnavailable(error: _cameraError),
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
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: IconButton.filledTonal(
                      tooltip: '갤러리',
                      onPressed: _isPickingImage ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _CaptureButton(
                      isCapturing: _isCapturing,
                      onPressed: _capturePhoto,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filledTonal(
                          tooltip: '텍스트로 시작',
                          onPressed: widget.onTextSelected,
                          icon: const Icon(Icons.text_fields),
                        ),
                        const SizedBox(height: 10),
                        IconButton.filledTonal(
                          tooltip: '그리기로 시작',
                          onPressed: widget.onDrawingSelected,
                          icon: const Icon(Icons.brush_outlined),
                        ),
                      ],
                    ),
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

class _CoveringCameraPreview extends StatelessWidget {
  const _CoveringCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const SizedBox.expand();
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.isCapturing, required this.onPressed});

  final bool isCapturing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '촬영',
      onPressed: isCapturing ? null : onPressed,
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
          style: const TextStyle(color: Colors.white, height: 1.5),
        ),
      ),
    );
  }
}
