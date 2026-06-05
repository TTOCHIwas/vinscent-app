import 'package:flutter/material.dart';

import '../../data/character_drawing.dart';

class CharacterCanvas extends StatelessWidget {
  const CharacterCanvas({
    super.key,
    required this.strokes,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  });

  final List<CharacterDrawingStroke> strokes;
  final ValueChanged<CharacterDrawingPoint> onStrokeStart;
  final ValueChanged<CharacterDrawingPoint> onStrokeUpdate;
  final VoidCallback onStrokeEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;

        return Center(
          child: GestureDetector(
            onPanStart: (details) {
              onStrokeStart(_normalize(details.localPosition, size));
            },
            onPanUpdate: (details) {
              onStrokeUpdate(_normalize(details.localPosition, size));
            },
            onPanEnd: (_) => onStrokeEnd(),
            onPanCancel: onStrokeEnd,
            child: CustomPaint(
              size: Size.square(size),
              painter: CharacterDrawingPainter(strokes: strokes),
            ),
          ),
        );
      },
    );
  }

  CharacterDrawingPoint _normalize(Offset position, double size) {
    return CharacterDrawingPoint(
      x: (position.dx / size).clamp(0.0, 1.0),
      y: (position.dy / size).clamp(0.0, 1.0),
    );
  }
}

class CharacterDrawingPainter extends CustomPainter {
  const CharacterDrawingPainter({required this.strokes});

  final List<CharacterDrawingStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());

    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke);
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Size size, CharacterDrawingStroke stroke) {
    if (stroke.points.isEmpty) {
      return;
    }

    final paint = Paint()
      ..strokeWidth = stroke.width * size.shortestSide
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..color = stroke.tool == CharacterDrawingTool.pen
          ? stroke.color
          : Colors.transparent
      ..blendMode = stroke.tool == CharacterDrawingTool.eraser
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

  Offset _denormalize(CharacterDrawingPoint point, Size size) {
    return Offset(point.x * size.width, point.y * size.height);
  }

  @override
  bool shouldRepaint(covariant CharacterDrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
