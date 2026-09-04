import 'package:flutter/material.dart';

import '../../assets/app_icons.dart';
import '../../presentation/widgets/app_svg_icon.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_drawing.dart';
import '../app_drawing_style.dart';
import 'app_color_palette.dart';

class AppDrawingToolbar extends StatelessWidget {
  const AppDrawingToolbar({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.selectedStrokeWidth,
    required this.isReadOnly,
    required this.canUndo,
    required this.canClear,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onPickColor,
    required this.onStrokeWidthChanged,
    required this.onUndoPressed,
    required this.onClearPressed,
    this.keyPrefix = 'character-drawing',
  });

  final AppDrawingTool selectedTool;
  final Color selectedColor;
  final double selectedStrokeWidth;
  final bool isReadOnly;
  final bool canUndo;
  final bool canClear;
  final ValueChanged<AppDrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final Future<Color?> Function() onPickColor;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onUndoPressed;
  final VoidCallback onClearPressed;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('$keyPrefix-toolbar'),
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xB8000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _ToolbarIconButton(
                    buttonKey: ValueKey('$keyPrefix-pen'),
                    tooltip: '펜',
                    icon: const Icon(Icons.edit),
                    isSelected: selectedTool == AppDrawingTool.pen,
                    onPressed: isReadOnly
                        ? null
                        : () => onToolChanged(AppDrawingTool.pen),
                  ),
                  const SizedBox(width: 6),
                  _ToolbarIconButton(
                    buttonKey: ValueKey('$keyPrefix-eraser'),
                    tooltip: '지우개',
                    icon: const AppSvgIcon(AppIcons.eraser),
                    isSelected: selectedTool == AppDrawingTool.eraser,
                    onPressed: isReadOnly
                        ? null
                        : () => onToolChanged(AppDrawingTool.eraser),
                  ),
                  const SizedBox(width: 6),
                  _ToolbarIconButton(
                    buttonKey: ValueKey('$keyPrefix-undo'),
                    tooltip: '되돌리기',
                    icon: const Icon(Icons.undo),
                    onPressed: canUndo ? onUndoPressed : null,
                  ),
                  const Spacer(),
                  _ToolbarIconButton(
                    buttonKey: ValueKey('$keyPrefix-clear'),
                    tooltip: '전체 삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: canClear ? onClearPressed : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppColorPalette(
                selectedColor: selectedColor,
                showSelection: selectedTool == AppDrawingTool.pen,
                onColorChanged: isReadOnly ? null : onColorChanged,
                onPickColor: isReadOnly ? null : onPickColor,
                keyPrefix: keyPrefix,
              ),
              const SizedBox(height: 4),
              _StrokeWidthSlider(
                selectedStrokeWidth: selectedStrokeWidth,
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                onChanged: isReadOnly ? null : onStrokeWidthChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isSelected = false,
  });

  final Key buttonKey;
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      color: Colors.white,
      disabledColor: Colors.white38,
      style: IconButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.actionPrimary
            : const Color(0x85000000),
        disabledBackgroundColor: const Color(0x52000000),
      ),
    );
  }
}

class _StrokeWidthSlider extends StatelessWidget {
  const _StrokeWidthSlider({
    required this.selectedStrokeWidth,
    required this.selectedTool,
    required this.selectedColor,
    required this.onChanged,
  });

  final double selectedStrokeWidth;
  final AppDrawingTool selectedTool;
  final Color selectedColor;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final previewColor = selectedTool == AppDrawingTool.pen
        ? selectedColor
        : Colors.white70;
    final previewDiameter = 8 + (selectedStrokeWidth * 360);

    return Row(
      children: [
        const Text('굵기', style: AppTextStyles.drawingToolLabel),
        const SizedBox(width: 10),
        SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: previewDiameter,
              height: previewDiameter,
              decoration: BoxDecoration(
                color: previewColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Expanded(
          child: Slider(
            min: AppDrawingStyle.minStrokeWidth,
            max: AppDrawingStyle.maxStrokeWidth,
            value: selectedStrokeWidth.clamp(
              AppDrawingStyle.minStrokeWidth,
              AppDrawingStyle.maxStrokeWidth,
            ),
            activeColor: Colors.white,
            inactiveColor: Colors.white38,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
