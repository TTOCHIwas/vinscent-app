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
            trackHeight: 2,
            trackShape: const _DirectionalStrokeTrack(),
            activeTrackColor: const Color(0xFF929292),
            inactiveTrackColor: const Color(0xFF929292),
            disabledInactiveTrackColor: const Color(0xFFB3B3B3),
            thumbColor: Colors.white,
            disabledThumbColor: Colors.white54,
            overlayColor: Colors.transparent,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: width * canvasExtent / 2,
              disabledThumbRadius: width * canvasExtent / 2,
              elevation: 0.5,
              pressedElevation: 4,
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

class _DirectionalStrokeTrack extends SliderTrackShape
    with BaseSliderTrackShape {
  const _DirectionalStrokeTrack();

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
    final color = ColorTween(
      begin: sliderTheme.disabledInactiveTrackColor,
      end: sliderTheme.inactiveTrackColor,
    ).evaluate(enableAnimation)!;
    final paint = Paint()..color = color;
    final canvas = context.canvas;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(1)),
      paint,
    );
    canvas.drawCircle(
      rect.centerLeft,
      textDirection == TextDirection.ltr ? 1.5 : 3.5,
      paint,
    );
    canvas.drawCircle(
      rect.centerRight,
      textDirection == TextDirection.ltr ? 3.5 : 1.5,
      paint,
    );
  }
}
