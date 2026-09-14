import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_typography.dart';
import '../data/story_card_film_look.dart';
import '../data/story_card_scene.dart';
import '../data/story_card_type.dart';
import 'story_card_film_shader.dart';

abstract final class StoryCardCanvasRenderer {
  static void paint({
    required Canvas canvas,
    required Size size,
    required StoryCardScene scene,
    ui.Image? backgroundImage,
    List<ui.Image?>? backgroundImages,
    ui.FragmentProgram? filmProgram,
    List<StoryCardStroke>? strokes,
    bool includeTextLayers = true,
  }) {
    final layout = StoryCardLayout.fromSize(type: scene.cardType, size: size);
    final images = backgroundImages ?? [backgroundImage];
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = scene.appearance.backgroundColor,
    );

    for (var index = 0; index < layout.photoRects.length; index++) {
      _drawBackground(
        canvas: canvas,
        destination: layout.photoRects[index],
        image: index < images.length ? images[index] : null,
        transform: scene.photoTransforms[index],
        backgroundColor: scene.appearance.backgroundColor,
        film: scene.photoFilms[index],
        filmProgram: filmProgram,
      );
    }
    final captionRect = layout.captionRect;
    if (captionRect != null) {
      _drawCaption(
        canvas,
        size,
        captionRect,
        scene.caption,
        scene.appearance.contentColor,
      );
    }
    _drawStrokes(canvas, size, strokes ?? scene.strokes);

    if (includeTextLayers) {
      for (final layer in scene.textLayers) {
        _drawTextLayer(canvas, size, layer);
      }
    }
  }

  static void _drawBackground({
    required Canvas canvas,
    required Rect destination,
    required ui.Image? image,
    required StoryCardBackgroundTransform transform,
    required Color backgroundColor,
    required StoryCardFilmState film,
    required ui.FragmentProgram? filmProgram,
  }) {
    canvas.save();
    canvas.clipRect(destination);
    canvas.drawRect(destination, Paint()..color = backgroundColor);
    if (image != null) {
      if (film.look != StoryCardFilmLook.original && filmProgram != null) {
        _drawFilteredBackground(
          canvas: canvas,
          destination: destination,
          image: image,
          transform: transform,
          backgroundColor: backgroundColor,
          film: film,
          filmProgram: filmProgram,
        );
        canvas.restore();
        return;
      }
      final coverScale = math.max(
        destination.width / image.width,
        destination.height / image.height,
      );
      final drawWidth = image.width * coverScale * transform.scale;
      final drawHeight = image.height * coverScale * transform.scale;
      final center = destination.center.translate(
        transform.offsetX * destination.width,
        transform.offsetY * destination.height,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(transform.rotation);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(
          center: Offset.zero,
          width: drawWidth,
          height: drawHeight,
        ),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  static void _drawFilteredBackground({
    required Canvas canvas,
    required Rect destination,
    required ui.Image image,
    required StoryCardBackgroundTransform transform,
    required Color backgroundColor,
    required StoryCardFilmState film,
    required ui.FragmentProgram filmProgram,
  }) {
    final mapping = StoryCardFilmImageMapping.cover(
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      destination: destination,
      transform: transform,
    );
    final shader = StoryCardFilmShader.create(
      program: filmProgram,
      outputSize: destination.size,
      outputOrigin: destination.topLeft,
      mapping: mapping,
      backgroundColor: backgroundColor,
      film: film,
      image: image,
    );
    try {
      canvas.drawRect(
        destination,
        Paint()
          ..shader = shader
          ..filterQuality = FilterQuality.high,
      );
    } finally {
      shader.dispose();
    }
  }

  static void _drawCaption(
    Canvas canvas,
    Size size,
    Rect captionRect,
    String? caption,
    Color textColor,
  ) {
    if (caption == null || caption.isEmpty || captionRect.isEmpty) {
      return;
    }

    final fontSize = size.width * storyCardCaptionFontSizeRatio;
    final painter = TextPainter(
      text: TextSpan(
        text: caption,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          height: AppTypography.bodyLineHeight,
          letterSpacing: AppTypography.letterSpacingFor(fontSize),
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
    final fontSize = size.width * storyCardTextFontSizeRatio;
    final painter = TextPainter(
      text: TextSpan(
        text: layer.text,
        style: AppTypography.withFontSize(
          AppTextStyles.homeBodyMedium.copyWith(
            color: layer.color,
            shadows: const [],
          ),
          fontSize,
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
