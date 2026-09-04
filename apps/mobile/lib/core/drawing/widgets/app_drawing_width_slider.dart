import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_drawing_style.dart';

class AppDrawingWidthSlider extends StatelessWidget {
  const AppDrawingWidthSlider({
    super.key,
    required this.canvasExtent,
    required this.value,
    required this.onChanged,
  });

  final double canvasExtent;
  final double value;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final minDiameter = AppDrawingStyle.minStrokeWidth * canvasExtent;
    final maxDiameter = AppDrawingStyle.maxStrokeWidth * canvasExtent;
    final width = value.clamp(
      AppDrawingStyle.minStrokeWidth,
      AppDrawingStyle.maxStrokeWidth,
    );
    final controlExtent = math.max(48.0, maxDiameter + 8);
    return SizedBox(
      height: controlExtent,
      child: Semantics(
        label: '굵기',
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: maxDiameter,
            trackShape: _TaperedStrokeTrack(minDiameter: minDiameter),
            activeTrackColor: Colors.white38,
            inactiveTrackColor: Colors.white38,
            disabledInactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            disabledThumbColor: Colors.white54,
            overlayColor: Colors.white12,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: width * canvasExtent / 2,
              disabledThumbRadius: width * canvasExtent / 2,
              elevation: 1,
              pressedElevation: 1,
            ),
            overlayShape: RoundSliderOverlayShape(
              overlayRadius: controlExtent / 2,
            ),
          ),
          child: Slider(
            // Keep the track and touch area fixed while the painted thumb grows.
            padding: EdgeInsets.symmetric(horizontal: controlExtent / 2),
            min: AppDrawingStyle.minStrokeWidth,
            max: AppDrawingStyle.maxStrokeWidth,
            value: width,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _TaperedStrokeTrack extends SliderTrackShape with BaseSliderTrackShape {
  const _TaperedStrokeTrack({required this.minDiameter});

  final double minDiameter;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final leftRadius = textDirection == TextDirection.ltr
        ? minDiameter / 2
        : rect.height / 2;
    final rightRadius = textDirection == TextDirection.ltr
        ? rect.height / 2
        : minDiameter / 2;
    final path = Path()
      ..moveTo(rect.left, rect.center.dy - leftRadius)
      ..lineTo(rect.right, rect.center.dy - rightRadius)
      ..lineTo(rect.right, rect.center.dy + rightRadius)
      ..lineTo(rect.left, rect.center.dy + leftRadius)
      ..close();
    final color = ColorTween(
      begin: sliderTheme.disabledInactiveTrackColor,
      end: sliderTheme.inactiveTrackColor,
    ).evaluate(enableAnimation)!;
    context.canvas.drawPath(path, Paint()..color = color);
    context.canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75,
    );
  }
}
