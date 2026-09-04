import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_drawing_style.dart';

class AppColorPalette extends StatefulWidget {
  const AppColorPalette({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
    required this.onPickColor,
    required this.keyPrefix,
    this.showSelection = true,
  });

  final Color selectedColor;
  final ValueChanged<Color>? onColorChanged;
  final Future<Color?> Function()? onPickColor;
  final String keyPrefix;
  final bool showSelection;

  @override
  State<AppColorPalette> createState() => _AppColorPaletteState();
}

class _AppColorPaletteState extends State<AppColorPalette> {
  bool _isPicking = false;

  Future<void> _pickColor() async {
    final pick = widget.onPickColor;
    if (_isPicking || pick == null || widget.onColorChanged == null) return;
    setState(() => _isPicking = true);
    try {
      final color = await pick();
      if (mounted && color != null) widget.onColorChanged?.call(color);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onColorChanged != null && !_isPicking;
    final iconColor = widget.selectedColor.computeLuminance() > 0.35
        ? Colors.black
        : Colors.white;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 48,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: IconButton(
                key: ValueKey('${widget.keyPrefix}-eyedropper'),
                tooltip: '스포이드',
                onPressed: isEnabled && widget.onPickColor != null
                    ? _pickColor
                    : null,
                icon: const Icon(LucideIcons.pipette, size: 21),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const CircleBorder(),
                  foregroundColor: iconColor,
                  disabledForegroundColor: iconColor.withValues(alpha: 0.45),
                  backgroundColor: widget.selectedColor,
                  disabledBackgroundColor: widget.selectedColor,
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ListView.builder(
              key: ValueKey('${widget.keyPrefix}-color-scroll'),
              scrollDirection: Axis.horizontal,
              itemCount: AppDrawingStyle.colorPalette.length,
              itemBuilder: (context, index) {
                final color = AppDrawingStyle.colorPalette[index];
                final isSelected =
                    widget.showSelection && color == widget.selectedColor;
                return Tooltip(
                  message: '색상 ${index + 1}',
                  child: Semantics(
                    selected: isSelected,
                    button: true,
                    child: Opacity(
                      opacity: isEnabled ? 1 : 0.45,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey('${widget.keyPrefix}-color-$index'),
                          customBorder: const CircleBorder(),
                          onTap: isEnabled
                              ? () => widget.onColorChanged?.call(color)
                              : null,
                          child: SizedBox(
                            width: 44,
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 40,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
