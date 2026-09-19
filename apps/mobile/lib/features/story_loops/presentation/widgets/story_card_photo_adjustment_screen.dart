import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/story_card_film_look.dart';
import '../../data/story_card_scene.dart';
import 'story_card_film_filtered_preview.dart';
import 'story_card_film_look_selector.dart';
import 'story_card_rotation_snap.dart';

typedef StoryCardPhotoAdjustmentDone =
    void Function(
      StoryCardBackgroundTransform transform,
      StoryCardFilmState film,
    );

class StoryCardPhotoAdjustmentScreen extends StatefulWidget {
  const StoryCardPhotoAdjustmentScreen({
    super.key,
    required this.imageBytes,
    required this.cropAspectRatio,
    required this.initialTransform,
    required this.initialFilm,
    required this.onBack,
    required this.onDone,
    required this.onRemove,
  });

  final Uint8List imageBytes;
  final double cropAspectRatio;
  final StoryCardBackgroundTransform initialTransform;
  final StoryCardFilmState initialFilm;
  final VoidCallback onBack;
  final StoryCardPhotoAdjustmentDone onDone;
  final VoidCallback onRemove;

  @override
  State<StoryCardPhotoAdjustmentScreen> createState() =>
      _StoryCardPhotoAdjustmentScreenState();
}

class _StoryCardPhotoAdjustmentScreenState
    extends State<StoryCardPhotoAdjustmentScreen>
    with SingleTickerProviderStateMixin {
  static const _resetDuration = Duration(milliseconds: 180);
  static const _rotationGestureThreshold = 0.002;

  ui.Image? _image;
  Object? _decodeError;
  late StoryCardBackgroundTransform _transform;
  late StoryCardFilmState _film;
  late final AnimationController _resetController;
  final _rotationSnapController = StoryCardRotationSnapController();
  StoryCardBackgroundTransform? _gestureStart;
  StoryCardBackgroundTransform? _resetStart;
  Offset _focalPointStart = Offset.zero;
  bool _rotationGestureDetected = false;
  bool _showAlignmentGuide = false;

  @override
  void initState() {
    super.initState();
    _transform = widget.initialTransform;
    _film = widget.initialFilm.seed > 0
        ? widget.initialFilm
        : widget.initialFilm.copyWith(seed: StoryCardFilmSeed.now());
    _resetController = AnimationController(
      vsync: this,
      duration: _resetDuration,
    )..addListener(_animateReset);
    unawaited(_decodeImage());
  }

  @override
  void dispose() {
    _resetController.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decodeImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (error) {
      if (mounted) {
        setState(() => _decodeError = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final frame = _cropFrame(context, constraints.biggest);
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                key: const ValueKey('story-card-photo-adjustment-gesture'),
                behavior: HitTestBehavior.opaque,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: (details) =>
                    _handleScaleUpdate(details, frame.size),
                onScaleEnd: _handleScaleEnd,
                child: _AdjustmentPhoto(
                  image: _image,
                  decodeError: _decodeError,
                  frame: frame,
                  transform: _transform,
                  film: _film,
                ),
              ),
              IgnorePointer(
                child: CustomPaint(painter: _CropMaskPainter(frame: frame)),
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  key: const ValueKey(
                    'story-card-photo-adjustment-alignment-guide',
                  ),
                  opacity: _showAlignmentGuide ? 1 : 0,
                  duration: const Duration(milliseconds: 140),
                  child: CustomPaint(
                    painter: _OrthogonalAlignmentGuidePainter(frame: frame),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: frame,
                child: IgnorePointer(
                  child: SizedBox(
                    key: const ValueKey(
                      'story-card-photo-adjustment-crop-frame',
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    key: const ValueKey('story-card-photo-adjustment-back'),
                    tooltip: '뒤로',
                    onPressed: widget.onBack,
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    key: const ValueKey('story-card-photo-adjustment-done'),
                    tooltip: '사진 적용',
                    onPressed: _completeAdjustment,
                    color: Colors.white,
                    icon: const Icon(Icons.check_rounded, size: 28),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: MediaQuery.paddingOf(context).bottom + 82,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const ValueKey('story-card-photo-adjustment-reset'),
                      tooltip: '사진 조정 초기화',
                      onPressed: _isTransformInitial ? null : _resetTransform,
                      color: Colors.white,
                      disabledColor: Colors.white38,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x8A000000),
                        disabledBackgroundColor: const Color(0x52000000),
                      ),
                      icon: const Icon(LucideIcons.rotateCcw, size: 23),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      key: const ValueKey('story-card-photo-adjustment-remove'),
                      tooltip: '사진 제거',
                      onPressed: widget.onRemove,
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x8A000000),
                      ),
                      icon: const Icon(LucideIcons.trash2, size: 23),
                    ),
                  ],
                ),
              ),
              Positioned(
                key: const ValueKey('story-card-photo-adjustment-filter'),
                left: 12,
                right: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 14,
                child: StoryCardFilmLookSelector(
                  selectedLook: _film.look,
                  onLookChanged: _selectFilm,
                  keyPrefix: 'story-card-photo-adjustment-film',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Rect _cropFrame(BuildContext context, Size size) {
    final padding = MediaQuery.paddingOf(context);
    final available = Rect.fromLTRB(
      16,
      padding.top + 68,
      size.width - 16,
      size.height - padding.bottom - 94,
    );
    if (available.isEmpty) {
      return Rect.zero;
    }
    final widthFromHeight = available.height * widget.cropAspectRatio;
    final width = math.min(available.width, widthFromHeight);
    final height = width / widget.cropAspectRatio;
    return Rect.fromCenter(
      center: available.center,
      width: width,
      height: height,
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _resetController.stop();
    _resetStart = null;
    _gestureStart = _transform;
    _focalPointStart = details.localFocalPoint;
    _rotationSnapController.begin(_transform.rotation);
    _rotationGestureDetected = false;
    if (_showAlignmentGuide) {
      setState(() => _showAlignmentGuide = false);
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, Size frameSize) {
    final start = _gestureStart;
    if (start == null || frameSize.isEmpty) {
      return;
    }
    final delta = details.localFocalPoint - _focalPointStart;
    _rotationGestureDetected =
        _rotationGestureDetected ||
        (details.pointerCount > 1 &&
            details.rotation.abs() > _rotationGestureThreshold);
    final rotation = _rotationSnapController.resolve(
      start.rotation + details.rotation,
    );
    final showAlignmentGuide = _rotationGestureDetected && rotation.isSnapped;
    if (showAlignmentGuide && (!_showAlignmentGuide || rotation.didSnap)) {
      unawaited(HapticFeedback.selectionClick());
    }
    setState(() {
      _transform = StoryCardBackgroundTransform(
        scale: (start.scale * details.scale)
            .clamp(storyCardMinBackgroundScale, storyCardMaxBackgroundScale)
            .toDouble(),
        offsetX: (start.offsetX + delta.dx / frameSize.width)
            .clamp(-2.0, 2.0)
            .toDouble(),
        offsetY: (start.offsetY + delta.dy / frameSize.height)
            .clamp(-2.0, 2.0)
            .toDouble(),
        rotation: rotation.angle,
      );
      _showAlignmentGuide = showAlignmentGuide;
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _gestureStart = null;
    _rotationSnapController.end();
    _rotationGestureDetected = false;
    if (_showAlignmentGuide) {
      setState(() => _showAlignmentGuide = false);
    }
  }

  bool get _isTransformInitial {
    const initial = StoryCardBackgroundTransform.initial();
    return (_transform.scale - initial.scale).abs() < 0.0001 &&
        (_transform.offsetX - initial.offsetX).abs() < 0.0001 &&
        (_transform.offsetY - initial.offsetY).abs() < 0.0001 &&
        (_transform.rotation - initial.rotation).abs() < 0.0001;
  }

  void _resetTransform() {
    _gestureStart = null;
    _rotationSnapController.end();
    _rotationGestureDetected = false;
    _resetStart = _transform;
    setState(() => _showAlignmentGuide = false);
    unawaited(HapticFeedback.selectionClick());
    _resetController.forward(from: 0);
  }

  void _animateReset() {
    final start = _resetStart;
    if (start == null) {
      return;
    }
    final progress = Curves.easeOutCubic.transform(_resetController.value);
    setState(() {
      _transform = _lerpTransform(
        start,
        const StoryCardBackgroundTransform.initial(),
        progress,
      );
    });
    if (_resetController.isCompleted) {
      _resetStart = null;
    }
  }

  void _completeAdjustment() {
    if (_resetController.isAnimating) {
      _resetController.stop();
      _resetStart = null;
      _transform = const StoryCardBackgroundTransform.initial();
    }
    widget.onDone(_transform, _film);
  }

  void _selectFilm(StoryCardFilmLook look) {
    setState(() {
      _film = _film.copyWith(look: look);
    });
  }
}

StoryCardBackgroundTransform _lerpTransform(
  StoryCardBackgroundTransform start,
  StoryCardBackgroundTransform end,
  double progress,
) {
  return StoryCardBackgroundTransform(
    scale: ui.lerpDouble(start.scale, end.scale, progress)!,
    offsetX: ui.lerpDouble(start.offsetX, end.offsetX, progress)!,
    offsetY: ui.lerpDouble(start.offsetY, end.offsetY, progress)!,
    rotation: ui.lerpDouble(start.rotation, end.rotation, progress)!,
  );
}

class _AdjustmentPhoto extends StatelessWidget {
  const _AdjustmentPhoto({
    required this.image,
    required this.decodeError,
    required this.frame,
    required this.transform,
    required this.film,
  });

  final ui.Image? image;
  final Object? decodeError;
  final Rect frame;
  final StoryCardBackgroundTransform transform;
  final StoryCardFilmState film;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (decodeError != null) {
      return const Center(
        child: Text('사진을 불러오지 못했어요.', style: TextStyle(color: Colors.white)),
      );
    }
    if (image == null || frame.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }

    final coverScale = math.max(
      frame.width / image.width,
      frame.height / image.height,
    );
    final imageSize = Size(image.width * coverScale, image.height * coverScale);
    final center = frame.center.translate(
      transform.offsetX * frame.width,
      transform.offsetY * frame.height,
    );

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: center.dx - imageSize.width / 2,
          top: center.dy - imageSize.height / 2,
          width: imageSize.width,
          height: imageSize.height,
          child: Transform.rotate(
            angle: transform.rotation,
            child: Transform.scale(
              scale: transform.scale,
              child: StoryCardFilmFilteredPreview(
                film: film,
                child: RawImage(
                  image: image,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CropMaskPainter extends CustomPainter {
  const _CropMaskPainter({required this.frame});

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final frameShape = RRect.fromRectAndRadius(frame, const Radius.circular(2));
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frameShape);
    canvas.drawPath(mask, Paint()..color = const Color(0x73000000));
    canvas.drawRRect(
      frameShape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xE6FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}

class _OrthogonalAlignmentGuidePainter extends CustomPainter {
  const _OrthogonalAlignmentGuidePainter({required this.frame});

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.isEmpty) {
      return;
    }
    final horizontalStart = Offset(frame.left, frame.center.dy);
    final horizontalEnd = Offset(frame.right, frame.center.dy);
    final verticalStart = Offset(frame.center.dx, frame.top);
    final verticalEnd = Offset(frame.center.dx, frame.bottom);
    final shadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 3;
    final guidePaint = Paint()
      ..color = const Color(0xE6FFFFFF)
      ..strokeWidth = 1;

    canvas
      ..drawLine(horizontalStart, horizontalEnd, shadowPaint)
      ..drawLine(verticalStart, verticalEnd, shadowPaint)
      ..drawLine(horizontalStart, horizontalEnd, guidePaint)
      ..drawLine(verticalStart, verticalEnd, guidePaint);
  }

  @override
  bool shouldRepaint(covariant _OrthogonalAlignmentGuidePainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}
