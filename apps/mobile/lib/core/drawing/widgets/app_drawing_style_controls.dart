import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

import 'app_color_palette.dart';
import 'app_drawing_width_slider.dart';

class AppDrawingStyleControls extends StatelessWidget {
  const AppDrawingStyleControls({
    super.key,
    required this.canvasExtent,
    required this.selectedColor,
    required this.selectedStrokeWidth,
    required this.showColorSelection,
    required this.onColorChanged,
    required this.onPickColor,
    required this.onStrokeWidthChanged,
    required this.keyPrefix,
    this.brightness = Brightness.dark,
    this.previewClearance = 0,
  });

  static const height = 120.0;

  final double canvasExtent;
  final Color selectedColor;
  final double selectedStrokeWidth;
  final bool showColorSelection;
  final ValueChanged<Color>? onColorChanged;
  final Future<Color?> Function()? onPickColor;
  final ValueChanged<double>? onStrokeWidthChanged;
  final String keyPrefix;
  final Brightness brightness;
  final double previewClearance;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: brightness == Brightness.light
          ? AppColors.background
          : const Color(0xCC000000),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            key: ValueKey('$keyPrefix-width-control'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppDrawingWidthSlider(
              previewClearance: previewClearance,
              brightness: brightness,
              canvasExtent: canvasExtent,
              value: selectedStrokeWidth,
              onChanged: onStrokeWidthChanged,
            ),
          ),
          SizedBox(
            key: ValueKey('$keyPrefix-color-palette'),
            width: double.infinity,
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AppColorPalette(
                brightness: brightness,
                keyPrefix: keyPrefix,
                selectedColor: selectedColor,
                showSelection: showColorSelection,
                onColorChanged: onColorChanged,
                onPickColor: onPickColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
