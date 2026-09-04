import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_drawing_style_controls.dart';

class AppDrawingCanvasLayout extends StatelessWidget {
  const AppDrawingCanvasLayout({
    super.key,
    required this.canvas,
    required this.maxCanvasSize,
    required this.controlsBuilder,
    this.canvasRegionKey,
  });

  final Widget canvas;
  final double maxCanvasSize;
  final Widget Function(double canvasExtent) controlsBuilder;
  final Key? canvasRegionKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasExtent = math.max(
          0.0,
          math.min(
            maxCanvasSize,
            math.min(
              constraints.maxWidth - 32,
              constraints.maxHeight - AppDrawingStyleControls.height - 32,
            ),
          ),
        );
        return Column(
          children: [
            Expanded(
              child: Padding(
                key: canvasRegionKey,
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: SizedBox.square(
                    dimension: canvasExtent,
                    child: canvas,
                  ),
                ),
              ),
            ),
            controlsBuilder(canvasExtent),
          ],
        );
      },
    );
  }
}
