import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/story_card_appearance.dart';
import '../../data/story_card_type.dart';
import 'story_card_type_picker.dart';

class StoryCardAppearancePicker extends StatelessWidget {
  const StoryCardAppearancePicker({
    super.key,
    required this.selectedType,
    required this.selectedBackgroundColor,
    required this.onTypeSelected,
    required this.onBackgroundColorSelected,
    required this.onCustomColorPressed,
    required this.typeKeyPrefix,
    required this.backgroundKeyPrefix,
  });

  final StoryCardType selectedType;
  final Color selectedBackgroundColor;
  final ValueChanged<StoryCardType> onTypeSelected;
  final ValueChanged<Color> onBackgroundColorSelected;
  final VoidCallback onCustomColorPressed;
  final String typeKeyPrefix;
  final String backgroundKeyPrefix;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: storyCardPickerMaxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: storyCardPickerSurfaceColor,
            borderRadius: BorderRadius.circular(storyCardPickerCornerRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 68,
                child: StoryCardTypeOptions(
                  selectedType: selectedType,
                  onSelected: onTypeSelected,
                  keyPrefix: typeKeyPrefix,
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: storyCardPickerDividerColor,
              ),
              SizedBox(
                height: 60,
                child: _StoryCardBackgroundOptions(
                  selectedColor: selectedBackgroundColor,
                  onSelected: onBackgroundColorSelected,
                  onCustomPressed: onCustomColorPressed,
                  keyPrefix: backgroundKeyPrefix,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryCardBackgroundOptions extends StatelessWidget {
  const _StoryCardBackgroundOptions({
    required this.selectedColor,
    required this.onSelected,
    required this.onCustomPressed,
    required this.keyPrefix,
  });

  final Color selectedColor;
  final ValueChanged<Color> onSelected;
  final VoidCallback onCustomPressed;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final isCustom = !storyCardBackgroundColorPalette.contains(selectedColor);
    return Row(
      children: [
        const SizedBox(width: 14),
        const Text(
          '배경',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: AppTypography.bodyLineHeight,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (
                  var index = 0;
                  index < storyCardBackgroundColorPalette.length;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(width: 8),
                  _BackgroundColorButton(
                    key: ValueKey('$keyPrefix-color-$index'),
                    color: storyCardBackgroundColorPalette[index],
                    isSelected:
                        selectedColor == storyCardBackgroundColorPalette[index],
                    onPressed: () =>
                        onSelected(storyCardBackgroundColorPalette[index]),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _CustomColorButton(
          key: ValueKey('$keyPrefix-custom'),
          color: selectedColor,
          isSelected: isCustom,
          onPressed: onCustomPressed,
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

class _BackgroundColorButton extends StatelessWidget {
  const _BackgroundColorButton({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '배경색 선택',
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '배경색 선택',
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: color.computeLuminance() > 0.9
                    ? Border.all(color: const Color(0x52000000))
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  const _CustomColorButton({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected && color.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    return Tooltip(
      message: '직접 색상 선택',
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '직접 색상 선택',
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isSelected ? color : const Color(0x52000000),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white54,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(Icons.palette_outlined, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}
