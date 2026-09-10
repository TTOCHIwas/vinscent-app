import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StoryCardCameraFocusOverlay extends StatelessWidget {
  const StoryCardCameraFocusOverlay({
    super.key,
    required this.normalizedPoint,
    required this.exposureOffset,
    required this.minimumExposureOffset,
    required this.maximumExposureOffset,
    required this.onExposureChanged,
    required this.onExposureChangeStarted,
    required this.onExposureChangeEnded,
  });

  final Offset normalizedPoint;
  final double exposureOffset;
  final double minimumExposureOffset;
  final double maximumExposureOffset;
  final ValueChanged<double> onExposureChanged;
  final VoidCallback onExposureChangeStarted;
  final VoidCallback onExposureChangeEnded;

  bool get _canAdjustExposure =>
      minimumExposureOffset.isFinite &&
      maximumExposureOffset.isFinite &&
      minimumExposureOffset < maximumExposureOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final focusCenter = Offset(
          normalizedPoint.dx * viewport.width,
          normalizedPoint.dy * viewport.height,
        );
        const indicatorSize = 64.0;
        final indicatorLeft = _clamp(
          focusCenter.dx - indicatorSize / 2,
          8,
          viewport.width - indicatorSize - 8,
        );
        final indicatorTop = _clamp(
          focusCenter.dy - indicatorSize / 2,
          8,
          viewport.height - indicatorSize - 8,
        );

        final exposureControlWidth = math.min(120.0, viewport.width - 32);
        const exposureControlHeight = 48.0;
        final exposureControlLeft = _clamp(
          focusCenter.dx - exposureControlWidth / 2,
          16,
          viewport.width - exposureControlWidth - 16,
        );
        final preferredExposureControlTop =
            focusCenter.dy + indicatorSize / 2 + 8;
        final maximumExposureControlBottom = viewport.height - 112;
        final exposureControlTop =
            preferredExposureControlTop + exposureControlHeight <=
                maximumExposureControlBottom
            ? preferredExposureControlTop
            : focusCenter.dy - indicatorSize / 2 - 8 - exposureControlHeight;

        return Stack(
          children: [
            Positioned(
              left: indicatorLeft,
              top: indicatorTop,
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('story-card-camera-focus-indicator'),
                  size: const Size.square(indicatorSize),
                  painter: const _FocusRingPainter(),
                ),
              ),
            ),
            if (_canAdjustExposure)
              Positioned(
                left: exposureControlLeft,
                top: _clamp(
                  exposureControlTop,
                  16,
                  viewport.height - exposureControlHeight - 16,
                ),
                width: exposureControlWidth,
                child: _ExposureControl(
                  value: exposureOffset
                      .clamp(minimumExposureOffset, maximumExposureOffset)
                      .toDouble(),
                  minimum: minimumExposureOffset,
                  maximum: maximumExposureOffset,
                  onChanged: onExposureChanged,
                  onChangeStarted: onExposureChangeStarted,
                  onChangeEnded: onExposureChangeEnded,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 4) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0x3D000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) => false;
}

class _ExposureControl extends StatelessWidget {
  const _ExposureControl({
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
    required this.onChangeStarted,
    required this.onChangeEnded,
  });

  final double value;
  final double minimum;
  final double maximum;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeStarted;
  final VoidCallback onChangeEnded;

  double get _normalizedValue =>
      ((value - minimum) / (maximum - minimum)).clamp(0.0, 1.0).toDouble();

  void _updateExposure(double localDx, double width) {
    if (width <= 0) {
      return;
    }
    final normalized = (localDx / width).clamp(0.0, 1.0).toDouble();
    onChanged(minimum + (maximum - minimum) * normalized);
  }

  void _adjustSemantics(double direction) {
    final step = (maximum - minimum) / 10;
    onChangeStarted();
    onChanged((value + step * direction).clamp(minimum, maximum).toDouble());
    onChangeEnded();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const horizontalInset = 10.0;
        const sunSize = 22.0;
        final trackWidth = math.max(0.0, width - horizontalInset * 2);
        final sunCenter = horizontalInset + trackWidth * _normalizedValue;

        return Semantics(
          label: '밝기 조절',
          value: '${(_normalizedValue * 100).round()}%',
          increasedValue:
              '${((_normalizedValue + 0.1).clamp(0.0, 1.0) * 100).round()}%',
          decreasedValue:
              '${((_normalizedValue - 0.1).clamp(0.0, 1.0) * 100).round()}%',
          slider: true,
          onIncrease: () => _adjustSemantics(1),
          onDecrease: () => _adjustSemantics(-1),
          child: GestureDetector(
            key: const ValueKey('story-card-camera-exposure-slider'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              onChangeStarted();
              _updateExposure(details.localPosition.dx, width);
              onChangeEnded();
            },
            onHorizontalDragStart: (details) {
              onChangeStarted();
              _updateExposure(details.localPosition.dx, width);
            },
            onHorizontalDragUpdate: (details) {
              _updateExposure(details.localPosition.dx, width);
            },
            onHorizontalDragEnd: (_) => onChangeEnded(),
            onHorizontalDragCancel: onChangeEnded,
            child: SizedBox(
              height: 48,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ExposureTrackPainter(
                        sunCenter: sunCenter,
                        horizontalInset: horizontalInset,
                        sunRadius: sunSize / 2,
                      ),
                    ),
                  ),
                  Positioned(
                    left: sunCenter - sunSize / 2,
                    top: (48 - sunSize) / 2,
                    child: const Icon(
                      LucideIcons.sun,
                      color: Colors.white,
                      size: sunSize,
                      shadows: [
                        Shadow(color: Color(0xA6000000), blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExposureTrackPainter extends CustomPainter {
  const _ExposureTrackPainter({
    required this.sunCenter,
    required this.horizontalInset,
    required this.sunRadius,
  });

  final double sunCenter;
  final double horizontalInset;
  final double sunRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final leftEnd = sunCenter - sunRadius - 5;
    final rightStart = sunCenter + sunRadius + 5;
    final trackEnd = size.width - horizontalInset;

    _drawSegment(
      canvas,
      Offset(horizontalInset, centerY),
      Offset(leftEnd, centerY),
    );
    _drawSegment(
      canvas,
      Offset(rightStart, centerY),
      Offset(trackEnd, centerY),
    );
  }

  void _drawSegment(Canvas canvas, Offset start, Offset end) {
    if (end.dx <= start.dx) {
      return;
    }
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = const Color(0x99000000)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ExposureTrackPainter oldDelegate) {
    return oldDelegate.sunCenter != sunCenter ||
        oldDelegate.horizontalInset != horizontalInset ||
        oldDelegate.sunRadius != sunRadius;
  }
}

double _clamp(double value, double minimum, double maximum) {
  if (maximum <= minimum) {
    return minimum;
  }
  return value.clamp(minimum, maximum).toDouble();
}
