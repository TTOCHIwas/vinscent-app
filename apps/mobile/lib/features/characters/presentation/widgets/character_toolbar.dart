import 'package:flutter/material.dart';

import '../../../../core/assets/app_icons.dart';
import '../../../../core/presentation/widgets/app_svg_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/character_drawing.dart';

const characterColorPalette = [
  Color(0xFF111111),
  Color(0xFF6F737C),
  Color(0xFFFFFFFF),
  Color(0xFFE94B5F),
  Color(0xFFF4932F),
  Color(0xFFF7D748),
  Color(0xFF39B871),
  Color(0xFF3E8EDE),
  Color(0xFF8C5BEA),
  Color(0xFFE56BAA),
];

const characterThinStrokeWidth = 0.012;
const characterNormalStrokeWidth = 0.022;
const characterThickStrokeWidth = 0.038;
const characterMinStrokeWidth = characterThinStrokeWidth;
const characterMaxStrokeWidth = characterThickStrokeWidth;

class CharacterToolbar extends StatelessWidget {
  const CharacterToolbar({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.selectedStrokeWidth,
    required this.isReadOnly,
    required this.canUndo,
    required this.canClear,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onUndoPressed,
    required this.onClearPressed,
  });

  final CharacterDrawingTool selectedTool;
  final Color selectedColor;
  final double selectedStrokeWidth;
  final bool isReadOnly;
  final bool canUndo;
  final bool canClear;
  final ValueChanged<CharacterDrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onUndoPressed;
  final VoidCallback onClearPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('character-drawing-toolbar'),
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
                    buttonKey: const ValueKey('character-drawing-pen'),
                    tooltip: '펜',
                    icon: const Icon(Icons.edit),
                    isSelected: selectedTool == CharacterDrawingTool.pen,
                    onPressed: isReadOnly
                        ? null
                        : () => onToolChanged(CharacterDrawingTool.pen),
                  ),
                  const SizedBox(width: 6),
                  _ToolbarIconButton(
                    buttonKey: const ValueKey('character-drawing-eraser'),
                    tooltip: '지우개',
                    icon: const AppSvgIcon(AppIcons.eraser),
                    isSelected: selectedTool == CharacterDrawingTool.eraser,
                    onPressed: isReadOnly
                        ? null
                        : () => onToolChanged(CharacterDrawingTool.eraser),
                  ),
                  const SizedBox(width: 6),
                  _ToolbarIconButton(
                    buttonKey: const ValueKey('character-drawing-undo'),
                    tooltip: '되돌리기',
                    icon: const Icon(Icons.undo),
                    onPressed: canUndo ? onUndoPressed : null,
                  ),
                  const Spacer(),
                  _ToolbarIconButton(
                    buttonKey: const ValueKey('character-drawing-clear'),
                    tooltip: '전체 삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: canClear ? onClearPressed : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (
                    var index = 0;
                    index < characterColorPalette.length;
                    index++
                  )
                    _ColorSwatch(
                      swatchKey: ValueKey('character-drawing-color-$index'),
                      color: characterColorPalette[index],
                      isEnabled: !isReadOnly,
                      isSelected:
                          selectedTool == CharacterDrawingTool.pen &&
                          characterColorPalette[index] == selectedColor,
                      onTap: () => onColorChanged(characterColorPalette[index]),
                    ),
                ],
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

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.swatchKey,
    required this.color,
    required this.isEnabled,
    required this.isSelected,
    required this.onTap,
  });

  final Key swatchKey;
  final Color color;
  final bool isEnabled;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          key: swatchKey,
          onTap: isEnabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white54,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color == AppColors.white
                      ? Colors.black26
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        ),
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
  final CharacterDrawingTool selectedTool;
  final Color selectedColor;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final previewColor = selectedTool == CharacterDrawingTool.pen
        ? selectedColor
        : Colors.white70;
    final previewDiameter = 8 + (selectedStrokeWidth * 360);

    return Row(
      children: [
        const Text('굵기', style: TextStyle(color: Colors.white, fontSize: 13)),
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
            min: characterMinStrokeWidth,
            max: characterMaxStrokeWidth,
            value: selectedStrokeWidth.clamp(
              characterMinStrokeWidth,
              characterMaxStrokeWidth,
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
