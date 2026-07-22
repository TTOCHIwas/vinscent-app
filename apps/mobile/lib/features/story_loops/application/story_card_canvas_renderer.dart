import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../data/story_card_scene.dart';

abstract final class StoryCardCanvasRenderer {
  static void paint({
    required Canvas canvas,
    required Size size,
    required StoryCardScene scene,
    required ui.Image? backgroundImage,
    List<StoryCardStroke>? strokes,
    bool includeTextLayers = true,
  }) {
    final layout = StoryCardPolaroidLayout.fromSize(size);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    _drawBackground(
      canvas: canvas,
      layout: layout,
      image: backgroundImage,
      transform: scene.backgroundTransform,
      canvasBackground: scene.canvasBackground,
    );
    _drawCaption(canvas, size, layout.captionRect, scene.caption);
    _drawStrokes(canvas, size, strokes ?? scene.strokes);

    if (includeTextLayers) {
      for (final layer in scene.textLayers) {
        _drawTextLayer(canvas, size, layer);
      }
    }
  }

  static void _drawBackground({
    required Canvas canvas,
    required StoryCardPolaroidLayout layout,
    required ui.Image? image,
    required StoryCardBackgroundTransform transform,
    required StoryCardCanvasBackground canvasBackground,
  }) {
    canvas.save();
    canvas.clipRect(layout.photoRect);
    canvas.drawRect(layout.photoRect, Paint()..color = canvasBackground.color);
    if (image != null) {
      final coverScale = math.max(
        layout.photoRect.width / image.width,
        layout.photoRect.height / image.height,
      );
      final drawWidth = image.width * coverScale * transform.scale;
      final drawHeight = image.height * coverScale * transform.scale;
      final offsetX =
          layout.photoRect.left +
          (layout.photoRect.width - drawWidth) / 2 +
          transform.offsetX * layout.photoRect.width;
      final offsetY =
          layout.photoRect.top +
          (layout.photoRect.height - drawHeight) / 2 +
          transform.offsetY * layout.photoRect.height;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight),
        Paint()..filterQuality = FilterQuality.high,
      );
    }
    canvas.restore();
  }

  static void _drawCaption(
    Canvas canvas,
    Size size,
    Rect captionRect,
    String? caption,
  ) {
    if (caption == null || caption.isEmpty || captionRect.isEmpty) {
      return;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: caption,
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
      ellipsis: '\u2026',
    )..layout(minWidth: captionRect.width, maxWidth: captionRect.width);
    painter.paint(
      canvas,
      Offset(
        captionRect.left,
        captionRect.top + (captionRect.height - painter.height) / 2,
      ),
    );
  }

  static void _drawStrokes(
    Canvas canvas,
    Size size,
    List<StoryCardStroke> strokes,
  ) {
    if (strokes.isEmpty) {
      return;
    }

    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke);
    }
    canvas.restore();
  }

  static void _drawStroke(Canvas canvas, Size size, StoryCardStroke stroke) {
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

  static void _drawTextLayer(
    Canvas canvas,
    Size size,
    StoryCardTextLayer layer,
  ) {
    final textWidth = size.width * 0.72;
    final painter = TextPainter(
      text: TextSpan(
        text: layer.text,
        style: AppTextStyles.homeBodyMedium.copyWith(
          color: layer.color,
          fontSize: size.width * storyCardTextFontSizeRatio,
          shadows: const [],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textWidth);

    canvas.save();
    canvas.translate(layer.x * size.width, layer.y * size.height);
    canvas.rotate(layer.rotation);
    canvas.scale(layer.scale);
    painter.paint(canvas, Offset(-textWidth / 2, -painter.height / 2));
    canvas.restore();
  }

  static Offset _denormalize(StoryCardPoint point, Size size) {
    return Offset(point.x * size.width, point.y * size.height);
  }
}
