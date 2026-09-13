import 'package:flutter/material.dart';

import '../../data/story_card_type.dart';

class StoryCardTypeIcon extends StatelessWidget {
  const StoryCardTypeIcon({
    super.key,
    required this.type,
    this.size = 24,
    this.color = Colors.white,
  });

  final StoryCardType type;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * type.canvasAspectRatio,
      height: size,
      child: CustomPaint(
        painter: StoryCardTypeIconPainter(type: type, color: color),
      ),
    );
  }
}

class StoryCardTypeIconPainter extends CustomPainter {
  const StoryCardTypeIconPainter({required this.type, required this.color});

  final StoryCardType type;
  final Color color;
  Color get fillColor => color;
  double get cornerRadius => 1;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = (size.shortestSide * 0.07).clamp(1.0, 1.8);
    final outer = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    const outerRadius = Radius.circular(1);
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
    final fill = Paint()..color = color;
    const cellRadius = Radius.circular(1);

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
  bool shouldRepaint(covariant StoryCardTypeIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
