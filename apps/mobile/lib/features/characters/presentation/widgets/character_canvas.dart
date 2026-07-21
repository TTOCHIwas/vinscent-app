import 'package:flutter/material.dart';

import '../../../../core/drawing/app_drawing.dart';
import '../../../../core/drawing/app_drawing_painter.dart';

class CharacterCanvas extends StatefulWidget {
  const CharacterCanvas({
    super.key,
    required this.strokes,
    required this.isReadOnly,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  });

  final List<AppDrawingStroke> strokes;
  final bool isReadOnly;
  final ValueChanged<AppDrawingPoint> onStrokeStart;
  final ValueChanged<AppDrawingPoint> onStrokeUpdate;
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
              painter: AppDrawingPainter(strokes: widget.strokes),
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

  AppDrawingPoint _normalize(Offset position, double size) {
    return AppDrawingPoint(
      x: (position.dx / size).clamp(0.0, 1.0),
      y: (position.dy / size).clamp(0.0, 1.0),
    );
  }
}
