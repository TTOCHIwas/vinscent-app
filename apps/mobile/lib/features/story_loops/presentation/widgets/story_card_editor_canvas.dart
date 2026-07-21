import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../application/story_card_editor_session.dart';
import '../../data/story_card_scene.dart';

class StoryCardEditorCanvas extends StatefulWidget {
  const StoryCardEditorCanvas({
    super.key,
    required this.backgroundImage,
    required this.scene,
    required this.visibleStrokes,
    required this.interactionMode,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
    required this.onBackgroundScaleStart,
    required this.onBackgroundScaleUpdate,
    required this.onTextLayerScaleStart,
    required this.onTextLayerScaleUpdate,
    required this.onTextLayerScaleEnd,
  });

  final ui.Image? backgroundImage;
  final StoryCardScene scene;
  final List<StoryCardStroke> visibleStrokes;
  final StoryCardEditorTool interactionMode;
  final void Function(StoryCardPoint point, int pointer) onStrokeStart;
  final void Function(StoryCardPoint point, int pointer) onStrokeUpdate;
  final ValueChanged<int> onStrokeEnd;
  final ValueChanged<ScaleStartDetails> onBackgroundScaleStart;
  final void Function(ScaleUpdateDetails details, Size size)
  onBackgroundScaleUpdate;
  final void Function(String layerId, ScaleStartDetails details)
  onTextLayerScaleStart;
  final void Function(String layerId, ScaleUpdateDetails details, Size size)
  onTextLayerScaleUpdate;
  final VoidCallback onTextLayerScaleEnd;

  @override
  State<StoryCardEditorCanvas> createState() => _StoryCardEditorCanvasState();
}

class _StoryCardEditorCanvasState extends State<StoryCardEditorCanvas> {
  final Set<int> _activePointers = {};
  final Map<int, String> _textPointerTargets = {};

  String? _lockedTextLayerId;
  bool _isBackgroundTransformLocked = false;

  @override
  void didUpdateWidget(covariant StoryCardEditorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final layerIds = widget.scene.textLayers.map((layer) => layer.id).toSet();
    _textPointerTargets.removeWhere(
      (pointer, layerId) => !layerIds.contains(layerId),
    );
    if (!layerIds.contains(_lockedTextLayerId)) {
      _lockedTextLayerId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            _activePointers.add(event.pointer);
          },
          onPointerUp: _releaseCanvasPointer,
          onPointerCancel: _releaseCanvasPointer,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _handleScaleStart,
            onScaleUpdate: (details) => _handleScaleUpdate(details, size),
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _StoryCardPainter(
                        backgroundImage: widget.backgroundImage,
                        backgroundTransform: widget.scene.backgroundTransform,
                        canvasBackground: widget.scene.canvasBackground,
                        caption: widget.scene.caption,
                        strokes: widget.visibleStrokes,
                      ),
                    ),
                  ),
                  for (final layer in widget.scene.textLayers)
                    Positioned(
                      left: layer.x * size.width,
                      top: layer.y * size.height,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, -0.5),
                        child: Listener(
                          onPointerDown: (event) {
                            _textPointerTargets.putIfAbsent(
                              event.pointer,
                              () => layer.id,
                            );
                          },
                          onPointerUp: (event) {
                            _textPointerTargets.remove(event.pointer);
                          },
                          onPointerCancel: (event) {
                            _textPointerTargets.remove(event.pointer);
                          },
                          child: Transform.rotate(
                            key: ValueKey(
                              'story-card-text-transform-${layer.id}',
                            ),
                            angle: layer.rotation,
                            child: Transform.scale(
                              key: ValueKey(
                                'story-card-text-scale-${layer.id}',
                              ),
                              scale: layer.scale,
                              child: SizedBox(
                                width: size.width * .72,
                                child: Text(
                                  layer.text,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.homeBodyMedium.copyWith(
                                    color: layer.color,
                                    shadows: const [],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.interactionMode == StoryCardEditorTool.drawing)
                    Positioned.fill(
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) => widget.onStrokeStart(
                          _normalize(event.localPosition, size),
                          event.pointer,
                        ),
                        onPointerMove: (event) => widget.onStrokeUpdate(
                          _normalize(event.localPosition, size),
                          event.pointer,
                        ),
                        onPointerUp: (event) =>
                            widget.onStrokeEnd(event.pointer),
                        onPointerCancel: (event) =>
                            widget.onStrokeEnd(event.pointer),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    final lockedTextLayerId = _lockedTextLayerId;
    if (lockedTextLayerId != null) {
      widget.onTextLayerScaleStart(lockedTextLayerId, details);
      return;
    }

    if (_isBackgroundTransformLocked) {
      if (details.pointerCount >= 2) {
        widget.onBackgroundScaleStart(details);
      }
      return;
    }

    final textLayerId = _textPointerTargets.isEmpty
        ? null
        : _textPointerTargets.values.first;
    if (textLayerId != null) {
      _lockedTextLayerId = textLayerId;
      widget.onTextLayerScaleStart(textLayerId, details);
      return;
    }

    if (details.pointerCount >= 2 &&
        widget.interactionMode != StoryCardEditorTool.drawing &&
        widget.backgroundImage != null) {
      _isBackgroundTransformLocked = true;
      widget.onBackgroundScaleStart(details);
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, Size size) {
    final lockedTextLayerId = _lockedTextLayerId;
    if (lockedTextLayerId != null) {
      widget.onTextLayerScaleUpdate(lockedTextLayerId, details, size);
      return;
    }

    if (_isBackgroundTransformLocked && details.pointerCount >= 2) {
      widget.onBackgroundScaleUpdate(details, size);
    }
  }

  void _releaseCanvasPointer(PointerEvent event) {
    _activePointers.remove(event.pointer);
    _textPointerTargets.remove(event.pointer);
    if (_activePointers.isNotEmpty) {
      return;
    }

    _lockedTextLayerId = null;
    _isBackgroundTransformLocked = false;
    _textPointerTargets.clear();
    widget.onTextLayerScaleEnd();
  }

  StoryCardPoint _normalize(Offset position, Size size) {
    return StoryCardPoint(
      x: (position.dx / size.width).clamp(0.0, 1.0),
      y: (position.dy / size.height).clamp(0.0, 1.0),
    );
  }
}

class _StoryCardPainter extends CustomPainter {
  const _StoryCardPainter({
    required this.backgroundImage,
    required this.backgroundTransform,
    required this.canvasBackground,
    required this.caption,
    required this.strokes,
  });

  final ui.Image? backgroundImage;
  final StoryCardBackgroundTransform backgroundTransform;
  final StoryCardCanvasBackground canvasBackground;
  final String? caption;
  final List<StoryCardStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = StoryCardPolaroidLayout.fromSize(size);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    canvas.save();
    canvas.clipRect(layout.photoRect);
    canvas.drawRect(layout.photoRect, Paint()..color = canvasBackground.color);
    final image = backgroundImage;
    if (image != null) {
      final coverScale =
          (layout.photoRect.width / image.width).compareTo(
                layout.photoRect.height / image.height,
              ) >=
              0
          ? layout.photoRect.width / image.width
          : layout.photoRect.height / image.height;
      final drawWidth = image.width * coverScale * backgroundTransform.scale;
      final drawHeight = image.height * coverScale * backgroundTransform.scale;
      final offsetX =
          layout.photoRect.left +
          (layout.photoRect.width - drawWidth) / 2 +
          backgroundTransform.offsetX * layout.photoRect.width;
      final offsetY =
          layout.photoRect.top +
          (layout.photoRect.height - drawHeight) / 2 +
          backgroundTransform.offsetY * layout.photoRect.height;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight),
        Paint(),
      );
    }
    canvas.restore();

    _drawCaption(canvas, size, layout.captionRect);

    if (strokes.isNotEmpty) {
      final bounds = Offset.zero & size;
      canvas.saveLayer(bounds, Paint());
      for (final stroke in strokes) {
        _drawStroke(canvas, size, stroke);
      }
      canvas.restore();
    }
  }

  void _drawCaption(Canvas canvas, Size size, Rect captionRect) {
    final value = caption;
    if (value == null || value.isEmpty || captionRect.isEmpty) {
      return;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: const Color(0xFF222222),
          fontSize: size.width * storyCardCaptionFontSizeRatio,
          fontWeight: FontWeight.w500,
          height: 1.3,
          letterSpacing: 0,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: storyCardMaxCaptionLines,
      ellipsis: '…',
    )..layout(minWidth: captionRect.width, maxWidth: captionRect.width);
    painter.paint(
      canvas,
      Offset(
        captionRect.left,
        captionRect.top + (captionRect.height - painter.height) / 2,
      ),
    );
  }

  void _drawStroke(Canvas canvas, Size size, StoryCardStroke stroke) {
    if (stroke.points.isEmpty) {
      return;
    }

    final paint = Paint()
      ..strokeWidth = stroke.width * size.shortestSide
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..color = stroke.tool == StoryCardDrawingTool.pen
          ? stroke.color
          : Colors.transparent
      ..blendMode = stroke.tool == StoryCardDrawingTool.eraser
          ? BlendMode.clear
          : BlendMode.srcOver;

    if (stroke.points.length == 1) {
      final point = _denormalize(stroke.points.first, size);
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = paint.color
        ..blendMode = paint.blendMode;
      canvas.drawCircle(point, paint.strokeWidth / 2, fillPaint);
      return;
    }

    final path = Path();
    final first = _denormalize(stroke.points.first, size);
    path.moveTo(first.dx, first.dy);
    for (final point in stroke.points.skip(1)) {
      final offset = _denormalize(point, size);
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(path, paint);
  }

  Offset _denormalize(StoryCardPoint point, Size size) {
    return Offset(point.x * size.width, point.y * size.height);
  }

  @override
  bool shouldRepaint(covariant _StoryCardPainter oldDelegate) {
    return oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.backgroundTransform != backgroundTransform ||
        oldDelegate.canvasBackground != canvasBackground ||
        oldDelegate.caption != caption ||
        oldDelegate.strokes != strokes;
  }
}
