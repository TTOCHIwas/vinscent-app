import 'dart:typed_data';

import 'package:flutter/material.dart';

class AppColorSampleBuffer {
  AppColorSampleBuffer({
    required this.width,
    required this.height,
    required this.rgbaBytes,
  }) {
    if (width <= 0 || height <= 0 || rgbaBytes.length != width * height * 4) {
      throw ArgumentError('The RGBA buffer does not match its dimensions.');
    }
  }

  final int width;
  final int height;
  final Uint8List rgbaBytes;

  Color colorAt({required Offset position, required Rect canvasRect}) {
    if (canvasRect.isEmpty) {
      throw ArgumentError.value(canvasRect, 'canvasRect');
    }

    final normalizedX = ((position.dx - canvasRect.left) / canvasRect.width)
        .clamp(0.0, 1.0);
    final normalizedY = ((position.dy - canvasRect.top) / canvasRect.height)
        .clamp(0.0, 1.0);
    final pixelX = (normalizedX * width).floor().clamp(0, width - 1);
    final pixelY = (normalizedY * height).floor().clamp(0, height - 1);
    final offset = (pixelY * width + pixelX) * 4;

    return Color.fromARGB(
      rgbaBytes[offset + 3],
      rgbaBytes[offset],
      rgbaBytes[offset + 1],
      rgbaBytes[offset + 2],
    );
  }
}

class AppColorSampler extends StatefulWidget {
  const AppColorSampler({
    super.key,
    required this.sampleBuffer,
    required this.canvasRect,
    required this.onColorSelected,
    this.keyPrefix = 'drawing',
  });

  final AppColorSampleBuffer sampleBuffer;
  final Rect canvasRect;
  final ValueChanged<Color> onColorSelected;
  final String keyPrefix;

  @override
  State<AppColorSampler> createState() => _AppColorSamplerState();
}

class _AppColorSamplerState extends State<AppColorSampler> {
  int? _activePointer;
  late Offset _position;
  late Color _sampledColor;

  @override
  void initState() {
    super.initState();
    _position = widget.canvasRect.center;
    _sampledColor = _sampleAt(_position);
  }

  @override
  void didUpdateWidget(covariant AppColorSampler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvasRect != widget.canvasRect ||
        oldWidget.sampleBuffer != widget.sampleBuffer) {
      _position = _clampToCanvas(_position);
      _sampledColor = _sampleAt(_position);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const indicatorWidth = 72.0;
          const indicatorHeight = 82.0;
          const indicatorGap = 24.0;
          final showAbove = _position.dy - indicatorHeight - indicatorGap >= 8;
          final indicatorTop = showAbove
              ? _position.dy - indicatorHeight - indicatorGap
              : _position.dy + indicatorGap;
          final maximumLeft = constraints.maxWidth - indicatorWidth - 8;
          final indicatorLeft = (_position.dx - indicatorWidth / 2).clamp(
            8.0,
            maximumLeft < 8 ? 8.0 : maximumLeft,
          );

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: _position.dx - 10,
                top: _position.dy - 10,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 4),
                      ],
                    ),
                    child: const SizedBox.square(dimension: 20),
                  ),
                ),
              ),
              Positioned(
                left: indicatorLeft,
                top: indicatorTop,
                child: IgnorePointer(
                  child: Semantics(
                    label: '선택 중인 색상',
                    child: CustomPaint(
                      key: ValueKey('${widget.keyPrefix}-eyedropper-color'),
                      size: const Size(indicatorWidth, indicatorHeight),
                      painter: _ColorIndicatorPainter(
                        color: _sampledColor,
                        pointsDown: showAbove,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) {
      return;
    }
    _activePointer = event.pointer;
    _updatePosition(event.localPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _updatePosition(event.localPosition);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _updatePosition(event.localPosition);
    _activePointer = null;
    widget.onColorSelected(_sampledColor);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer == event.pointer) {
      _activePointer = null;
    }
  }

  void _updatePosition(Offset position) {
    final nextPosition = _clampToCanvas(position);
    final nextColor = _sampleAt(nextPosition);
    if (nextPosition == _position && nextColor == _sampledColor) {
      return;
    }
    setState(() {
      _position = nextPosition;
      _sampledColor = nextColor;
    });
  }

  Offset _clampToCanvas(Offset position) {
    return Offset(
      position.dx.clamp(widget.canvasRect.left, widget.canvasRect.right),
      position.dy.clamp(widget.canvasRect.top, widget.canvasRect.bottom),
    );
  }

  Color _sampleAt(Offset position) {
    return widget.sampleBuffer.colorAt(
      position: position,
      canvasRect: widget.canvasRect,
    );
  }
}

class _ColorIndicatorPainter extends CustomPainter {
  const _ColorIndicatorPainter({required this.color, required this.pointsDown});

  final Color color;
  final bool pointsDown;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.82,
        size.width * 0.08,
        size.height * 0.62,
        size.width * 0.08,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.08,
        size.height * 0.16,
        size.width * 0.26,
        2,
        size.width / 2,
        2,
      )
      ..cubicTo(
        size.width * 0.74,
        2,
        size.width * 0.92,
        size.height * 0.16,
        size.width * 0.92,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.92,
        size.height * 0.62,
        size.width * 0.62,
        size.height * 0.82,
        size.width / 2,
        size.height,
      )
      ..close();

    canvas.save();
    if (!pointsDown) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }
    canvas.drawShadow(path, Colors.black, 8, true);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ColorIndicatorPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pointsDown != pointsDown;
  }
}
