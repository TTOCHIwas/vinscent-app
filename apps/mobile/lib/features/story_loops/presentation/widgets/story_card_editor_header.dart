import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_back_button.dart';
import '../../../../core/theme/app_text_styles.dart';

class StoryCardEditorHeader extends StatelessWidget {
  const StoryCardEditorHeader({
    super.key,
    required this.canSave,
    required this.isSaving,
    required this.canDelete,
    required this.onBackPressed,
    required this.onDeletePressed,
    required this.onSavePressed,
  });

  final bool canSave;
  final bool isSaving;
  final bool canDelete;
  final VoidCallback onBackPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onSavePressed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x52000000),
      child: SizedBox(
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
                  iconSize: 30,
                ),
              ),
              const Text('오늘의 스토리', style: AppTextStyles.storyEditorTitle),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canDelete)
                      IconButton(
                        tooltip: '카드 삭제',
                        color: Colors.white,
                        onPressed: onDeletePressed,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    TextButton(
                      key: const ValueKey('story-card-editor-save'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      onPressed: canSave ? onSavePressed : null,
                      child: isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('올리기'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
