import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/story_card_film_look.dart';
import '../../data/story_card_scene.dart';
import 'story_card_film_filtered_preview.dart';
import 'story_card_film_look_selector.dart';

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
    extends State<StoryCardPhotoAdjustmentScreen> {
  ui.Image? _image;
  Object? _decodeError;
  late StoryCardBackgroundTransform _transform;
  late StoryCardFilmState _film;
  StoryCardBackgroundTransform? _gestureStart;
  Offset _focalPointStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transform = widget.initialTransform;
    _film = widget.initialFilm.seed > 0
        ? widget.initialFilm
        : widget.initialFilm.copyWith(seed: StoryCardFilmSeed.now());
    unawaited(_decodeImage());
  }

  @override
  void dispose() {
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
                onScaleEnd: (_) => _gestureStart = null,
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
                    onPressed: () => widget.onDone(_transform, _film),
                    color: Colors.white,
                    icon: const Icon(Icons.check_rounded, size: 28),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: MediaQuery.paddingOf(context).bottom + 82,
                child: IconButton(
                  key: const ValueKey('story-card-photo-adjustment-remove'),
                  tooltip: '사진 제거',
                  onPressed: widget.onRemove,
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x8A000000),
                  ),
                  icon: const Icon(LucideIcons.trash2, size: 23),
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
    _gestureStart = _transform;
    _focalPointStart = details.localFocalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, Size frameSize) {
    final start = _gestureStart;
    if (start == null || frameSize.isEmpty) {
      return;
    }
    final delta = details.localFocalPoint - _focalPointStart;
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
        rotation: start.rotation + details.rotation,
      );
    });
  }

  void _selectFilm(StoryCardFilmLook look) {
    setState(() {
      _film = _film.copyWith(look: look);
    });
  }
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
