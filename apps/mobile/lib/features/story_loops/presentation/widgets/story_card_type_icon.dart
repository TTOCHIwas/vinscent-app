import 'package:flutter/material.dart';

import '../../data/story_card_type.dart';

class StoryCardTypeIcon extends StatelessWidget {
  const StoryCardTypeIcon({
    super.key,
    required this.type,
    this.size = 24,
    this.color = Colors.white,
    this.fillColor,
  });

  final StoryCardType type;
  final double size;
  final Color color;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * type.canvasAspectRatio,
      height: size,
      child: CustomPaint(
        painter: _StoryCardTypeIconPainter(
          type: type,
          color: color,
          fillColor: fillColor ?? color.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _StoryCardTypeIconPainter extends CustomPainter {
  const _StoryCardTypeIconPainter({
    required this.type,
    required this.color,
    required this.fillColor,
  });

  final StoryCardType type;
  final Color color;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = (size.shortestSide * 0.07).clamp(1.0, 1.8);
    final outer = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final outerRadius = Radius.circular(
      (size.shortestSide * 0.08).clamp(1.0, 2.0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, outerRadius),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (type == StoryCardType.fullBleed) {
      return;
    }

    final layout = StoryCardLayout.fromSize(type: type, size: outer.size);
    final fill = Paint()..color = fillColor;
    final cellRadius = Radius.circular(
      (size.shortestSide * 0.045).clamp(0.7, 1.2),
    );

    final photoInset = (size.shortestSide * 0.015).clamp(0.15, 0.35);
    for (final photoRect in layout.photoRects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          photoRect.shift(outer.topLeft).deflate(photoInset),
          cellRadius,
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StoryCardTypeIconPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor;
  }
}
