import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/story_card_type.dart';
import 'story_card_type_icon.dart';

class StoryCardTypePicker extends StatelessWidget {
  const StoryCardTypePicker({
    super.key,
    required this.selectedType,
    required this.onSelected,
    required this.keyPrefix,
  });

  final StoryCardType selectedType;
  final ValueChanged<StoryCardType> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xB3000000),
            borderRadius: BorderRadius.circular(2),
          ),
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (final type in StoryCardType.editorOrder)
                  Expanded(
                    child: _StoryCardTypeButton(
                      key: ValueKey(
                        '$keyPrefix-${type.storageValue.replaceAll('_', '-')}',
                      ),
                      type: type,
                      isSelected: type == selectedType,
                      onPressed: () => onSelected(type),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryCardTypeButton extends StatelessWidget {
  const _StoryCardTypeButton({
    super.key,
    required this.type,
    required this.isSelected,
    required this.onPressed,
  });

  final StoryCardType type;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final labelColor = isSelected ? Colors.white : const Color(0xA6FFFFFF);
    return Semantics(
      button: true,
      selected: isSelected,
      label: type.displayName,
      child: InkResponse(
        onTap: onPressed,
        radius: 34,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StoryCardTypeIcon(type: type, size: 25, color: Colors.white),
            const SizedBox(height: 5),
            Text(
              type.displayName,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                height: AppTypography.bodyLineHeight,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
