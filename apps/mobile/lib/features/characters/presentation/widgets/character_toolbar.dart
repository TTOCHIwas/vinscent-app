import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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
    required this.canClear,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onClearPressed,
  });

  final CharacterDrawingTool selectedTool;
  final Color selectedColor;
  final double selectedStrokeWidth;
  final bool isReadOnly;
  final bool canClear;
  final ValueChanged<CharacterDrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onClearPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ToolButton(
                icon: Icons.edit,
                label: '펜',
                isSelected: selectedTool == CharacterDrawingTool.pen,
                isEnabled: !isReadOnly,
                onTap: () => onToolChanged(CharacterDrawingTool.pen),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ToolButton(
                icon: Icons.cleaning_services_outlined,
                label: '지우개',
                isSelected: selectedTool == CharacterDrawingTool.eraser,
                isEnabled: !isReadOnly,
                onTap: () => onToolChanged(CharacterDrawingTool.eraser),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ToolButton(
                icon: Icons.delete_outline,
                label: '전체 삭제',
                isSelected: false,
                isEnabled: !isReadOnly && canClear,
                onTap: onClearPressed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in characterColorPalette)
              _ColorSwatch(
                color: color,
                isEnabled: !isReadOnly,
                isSelected:
                    selectedTool == CharacterDrawingTool.pen &&
                    color == selectedColor,
                onTap: () => onColorChanged(color),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _StrokeWidthSlider(
          selectedStrokeWidth: selectedStrokeWidth,
          selectedTool: selectedTool,
          selectedColor: selectedColor,
          onChanged: isReadOnly ? null : onStrokeWidthChanged,
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isEnabled = true,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final foreground = !isEnabled
        ? AppColors.actionDisabledContent
        : isSelected
        ? AppColors.textInverse
        : AppColors.textPrimary;
    final background = !isEnabled
        ? AppColors.actionDisabled
        : isSelected
        ? AppColors.actionPrimary
        : AppColors.white;

    return Material(
      color: background,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.wireframeBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.homeCharacterLabel.copyWith(
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.isEnabled,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isEnabled;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? AppColors.actionPrimary
                  : AppColors.wireframeBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: color == AppColors.white
                    ? AppColors.wireframeBorder
                    : Colors.transparent,
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
        : AppColors.textMuted;
    final previewDiameter = 8 + (selectedStrokeWidth * 360);

    return Material(
      color: AppColors.white,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.wireframeBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text('굵기', style: AppTextStyles.homeCharacterLabel),
            const SizedBox(width: 12),
            SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: Container(
                  width: previewDiameter,
                  height: previewDiameter,
                  decoration: BoxDecoration(
                    color: previewColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.wireframeBorder),
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
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
