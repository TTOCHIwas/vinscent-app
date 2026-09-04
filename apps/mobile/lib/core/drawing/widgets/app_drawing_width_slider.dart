import 'package:flutter/material.dart';

import '../app_drawing_style.dart';
import '../../theme/app_colors.dart';

class AppDrawingWidthSlider extends StatefulWidget {
  const AppDrawingWidthSlider({
    super.key,
    required this.canvasExtent,
    required this.value,
    required this.onChanged,
    this.brightness = Brightness.dark,
    this.previewClearance = 0,
  });

  final double canvasExtent;
  final double value;
  final ValueChanged<double>? onChanged;
  final Brightness brightness;
  final double previewClearance;

  @override
  State<AppDrawingWidthSlider> createState() => _AppDrawingWidthSliderState();
}

class _AppDrawingWidthSliderState extends State<AppDrawingWidthSlider> {
  static const _trackPadding = 24.0;
  bool _isAdjusting = false;

  @override
  Widget build(BuildContext context) {
    final isLight = widget.brightness == Brightness.light;
    final trackColor = isLight ? AppColors.textMuted : Colors.white70;
    final inactiveColor = isLight ? AppColors.settingsDivider : Colors.white38;
    final disabledColor = isLight ? AppColors.actionDisabled : Colors.white24;
    final width = widget.value.clamp(
      AppDrawingStyle.minStrokeWidth,
      AppDrawingStyle.maxStrokeWidth,
    );
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          _StrokeWidthMark(thickness: 1.5, color: trackColor),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fraction =
                    (width - AppDrawingStyle.minStrokeWidth) /
                    (AppDrawingStyle.maxStrokeWidth -
                        AppDrawingStyle.minStrokeWidth);
                final position = Directionality.of(context) == TextDirection.ltr
                    ? fraction
                    : 1 - fraction;
                final thumbX =
                    _trackPadding +
                    (constraints.maxWidth - _trackPadding * 2) * position;
                final diameter = width * widget.canvasExtent;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Semantics(
                      label: '굵기',
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          trackShape: const RoundedRectSliderTrackShape(),
                          activeTrackColor: trackColor,
                          inactiveTrackColor: inactiveColor,
                          disabledActiveTrackColor: disabledColor,
                          disabledInactiveTrackColor: disabledColor,
                          thumbColor: Colors.white,
                          disabledThumbColor: isLight
                              ? AppColors.actionDisabled
                              : Colors.white54,
                          overlayColor: Colors.transparent,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 10,
                            disabledThumbRadius: 10,
                            elevation: 1,
                            pressedElevation: 3,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: _trackPadding,
                          ),
                        ),
                        child: Slider(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _trackPadding,
                          ),
                          min: AppDrawingStyle.minStrokeWidth,
                          max: AppDrawingStyle.maxStrokeWidth,
                          value: width,
                          onChanged: widget.onChanged,
                          onChangeStart: (_) =>
                              setState(() => _isAdjusting = true),
                          onChangeEnd: (_) =>
                              setState(() => _isAdjusting = false),
                        ),
                      ),
                    ),
                    if (_isAdjusting && widget.onChanged != null)
                      Positioned(
                        bottom: 72 + widget.previewClearance,
                        left: (thumbX - diameter / 2).clamp(
                          0.0,
                          (constraints.maxWidth - diameter).clamp(
                            0.0,
                            double.infinity,
                          ),
                        ),
                        child: IgnorePointer(
                          child: Container(
                            key: const ValueKey('drawing-width-preview'),
                            width: diameter,
                            height: diameter,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          _StrokeWidthMark(thickness: 6, color: trackColor),
        ],
      ),
    );
  }
}

class _StrokeWidthMark extends StatelessWidget {
  const _StrokeWidthMark({required this.thickness, required this.color});

  final double thickness;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 16,
        child: Center(
          child: Container(
            width: 16,
            height: thickness,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(thickness / 2),
            ),
          ),
        ),
      ),
    );
  }
}
