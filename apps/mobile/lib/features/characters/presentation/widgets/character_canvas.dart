import 'package:flutter/material.dart';

import '../../data/character_drawing.dart';

class CharacterCanvas extends StatefulWidget {
  const CharacterCanvas({
    super.key,
    required this.strokes,
    required this.isReadOnly,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  });

  final List<CharacterDrawingStroke> strokes;
  final bool isReadOnly;
  final ValueChanged<CharacterDrawingPoint> onStrokeStart;
  final ValueChanged<CharacterDrawingPoint> onStrokeUpdate;
  final VoidCallback onStrokeEnd;

  @override
  State<CharacterCanvas> createState() => _CharacterCanvasState();
}

class _CharacterCanvasState extends State<CharacterCanvas> {
  int? _activePointer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;

        return Center(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: widget.isReadOnly
                ? null
                : (event) => _startStroke(event, size),
            onPointerMove: widget.isReadOnly
                ? null
                : (event) => _updateStroke(event, size),
            onPointerUp: widget.isReadOnly ? null : _endStroke,
            onPointerCancel: widget.isReadOnly ? null : _endStroke,
            child: CustomPaint(
              size: Size.square(size),
              painter: CharacterDrawingPainter(strokes: widget.strokes),
            ),
          ),
        );
      },
    );
  }

  void _startStroke(PointerDownEvent event, double size) {
    if (_activePointer != null) {
      return;
    }

    setState(() {
      _activePointer = event.pointer;
    });
    widget.onStrokeStart(_normalize(event.localPosition, size));
  }

  void _updateStroke(PointerMoveEvent event, double size) {
    if (_activePointer != event.pointer) {
      return;
    }

    widget.onStrokeUpdate(_normalize(event.localPosition, size));
  }

  void _endStroke(PointerEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }

    widget.onStrokeEnd();
    if (mounted) {
      setState(() {
        _activePointer = null;
      });
    }
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
