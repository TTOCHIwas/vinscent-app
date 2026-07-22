import 'package:flutter/material.dart';

import '../../application/story_card_editor_session.dart';
import 'story_card_editor_icon_button.dart';

class StoryCardEditorActionBar extends StatelessWidget {
  const StoryCardEditorActionBar({
    super.key,
    required this.interactionMode,
    required this.hasBackground,
    required this.onAddTextPressed,
    required this.onEditCaptionPressed,
    required this.onDrawingModePressed,
    required this.onBackgroundColorPressed,
  });

  final StoryCardEditorTool interactionMode;
  final bool hasBackground;
  final VoidCallback onAddTextPressed;
  final VoidCallback? onEditCaptionPressed;
  final VoidCallback onDrawingModePressed;
  final VoidCallback? onBackgroundColorPressed;

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
        if (onEditCaptionPressed != null) ...[
          const SizedBox(height: 8),
          StoryCardEditorIconButton(
            key: const ValueKey('story-card-caption-tool'),
            tooltip: '짧은 글',
            icon: Icons.short_text,
            onPressed: onEditCaptionPressed,
          ),
        ],
        const SizedBox(height: 8),
        StoryCardEditorIconButton(
          tooltip: '그리기',
          icon: Icons.brush_outlined,
          isSelected: interactionMode == StoryCardEditorTool.drawing,
          onPressed: onDrawingModePressed,
        ),
        if (!hasBackground) ...[
          const SizedBox(height: 8),
          StoryCardEditorIconButton(
            tooltip: '배경색 전환',
            icon: Icons.contrast,
            onPressed: onBackgroundColorPressed,
          ),
        ],
      ],
    );
  }
}
