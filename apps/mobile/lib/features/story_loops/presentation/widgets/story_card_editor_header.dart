import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import 'story_card_editor_style.dart';

class StoryCardEditorHeader extends StatelessWidget {
  const StoryCardEditorHeader({
    super.key,
    required this.canSave,
    required this.isSaving,
    required this.onBackPressed,
    required this.onSavePressed,
  });

  final bool canSave;
  final bool isSaving;
  final VoidCallback onBackPressed;
  final VoidCallback onSavePressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('story-card-editor-header-surface'),
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppBackButton(
                onPressed: onBackPressed,
                color: Colors.white,
                shadows: storyCardEditorControlShadows,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const ValueKey('story-card-editor-save'),
                tooltip: '카드 올리기',
                color: AppColors.brandAction,
                disabledColor: Colors.white38,
                onPressed: canSave ? onSavePressed : null,
                icon: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          color: AppColors.brandAction,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.check_rounded,
                        size: 26,
                        shadows: storyCardEditorControlShadows,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
