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
    return SizedBox.square(
      dimension: size,
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
    final strokeWidth = (size.shortestSide * 0.07).clamp(1.25, 1.8);
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

    final inset = size.shortestSide * 0.17;
    final content = outer.deflate(inset);
    final fill = Paint()..color = fillColor;
    final cellRadius = Radius.circular(
      (size.shortestSide * 0.045).clamp(0.7, 1.2),
    );

    switch (type) {
      case StoryCardType.fullBleed:
        return;
      case StoryCardType.polaroid:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              content.left,
              content.top,
              content.width,
              content.height * 0.68,
            ),
            cellRadius,
          ),
          fill,
        );
      case StoryCardType.fourCutGrid:
        final gap = size.shortestSide * 0.08;
        final cellWidth = (content.width - gap) / 2;
        final cellHeight = (content.height - gap) / 2;
        for (var row = 0; row < 2; row++) {
          for (var column = 0; column < 2; column++) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  content.left + column * (cellWidth + gap),
                  content.top + row * (cellHeight + gap),
                  cellWidth,
                  cellHeight,
                ),
                cellRadius,
              ),
              fill,
            );
          }
        }
      case StoryCardType.fourCutStrip:
        final gap = size.shortestSide * 0.055;
        final cellHeight = (content.height - gap * 3) / 4;
        for (var index = 0; index < 4; index++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                content.left,
                content.top + index * (cellHeight + gap),
                content.width,
                cellHeight,
              ),
              cellRadius,
            ),
            fill,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _StoryCardTypeIconPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor;
  }
}
