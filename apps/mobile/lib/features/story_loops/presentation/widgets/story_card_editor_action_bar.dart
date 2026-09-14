import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/story_card_editor_session.dart';
import '../../data/story_card_type.dart';
import 'story_card_editor_icon_button.dart';
import 'story_card_type_icon.dart';

class StoryCardEditorActionBar extends StatelessWidget {
  const StoryCardEditorActionBar({
    super.key,
    required this.interactionMode,
    required this.cardType,
    required this.onAddTextPressed,
    required this.onDrawingModePressed,
    required this.onCardTypePressed,
    this.onFilmPressed,
    this.isFilmSelected = false,
    this.isCardTypeSelected = false,
  });

  final StoryCardEditorTool interactionMode;
  final StoryCardType cardType;
  final VoidCallback onAddTextPressed;
  final VoidCallback onDrawingModePressed;
  final VoidCallback onCardTypePressed;
  final VoidCallback? onFilmPressed;
  final bool isFilmSelected;
  final bool isCardTypeSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StoryCardEditorIconButton(
          tooltip: '텍스트 추가',
          icon: Icons.text_fields,
          isSelected: interactionMode == StoryCardEditorTool.text,
          onPressed: onAddTextPressed,
        ),
        const SizedBox(height: 8),
        StoryCardEditorIconButton(
          tooltip: '그리기',
          icon: Icons.brush_outlined,
          isSelected: interactionMode == StoryCardEditorTool.drawing,
          onPressed: onDrawingModePressed,
        ),
        if (onFilmPressed != null) ...[
          const SizedBox(height: 8),
          StoryCardEditorIconButton(
            key: const ValueKey('story-card-film-tool'),
            tooltip: '필름',
            icon: LucideIcons.wandSparkles,
            isSelected: isFilmSelected,
            onPressed: onFilmPressed,
          ),
        ],
        const SizedBox(height: 8),
        StoryCardEditorIconButton(
          key: const ValueKey('story-card-type-tool'),
          tooltip: '카드 유형',
          iconWidget: StoryCardTypeIcon(type: cardType, size: 23),
          isSelected: isCardTypeSelected,
          onPressed: onCardTypePressed,
        ),
      ],
    );
  }
}
