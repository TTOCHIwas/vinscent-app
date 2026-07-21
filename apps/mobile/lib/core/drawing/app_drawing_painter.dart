import 'package:flutter/material.dart';

import 'app_drawing.dart';

class AppDrawingPainter extends CustomPainter {
  const AppDrawingPainter({required this.strokes});

  final List<AppDrawingStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());

    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke);
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Size size, AppDrawingStroke stroke) {
    if (stroke.points.isEmpty) {
      return;
    }

    final paint = Paint()
      ..strokeWidth = stroke.width * size.shortestSide
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..color = stroke.tool == AppDrawingTool.pen
          ? stroke.color
          : Colors.transparent
      ..blendMode = stroke.tool == AppDrawingTool.eraser
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

  Offset _denormalize(AppDrawingPoint point, Size size) {
    return Offset(point.x * size.width, point.y * size.height);
  }

  @override
  bool shouldRepaint(covariant AppDrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
