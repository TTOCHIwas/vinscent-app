import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/story_card_local_draft_repository.dart';

class StoryCardLocalDraftSheet extends StatelessWidget {
  const StoryCardLocalDraftSheet({
    super.key,
    required this.drafts,
    required this.onSelected,
  });

  final List<StoryCardLocalDraftSummary> drafts;
  final ValueChanged<StoryCardLocalDraftSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('임시 저장 카드', style: AppTextStyles.sectionTitle),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (drafts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 52),
                child: Text(
                  '임시 저장한 카드가 없어요.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.homeBody.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              )
            else
              Flexible(
                child: GridView.builder(
                  key: const ValueKey('story-card-local-draft-grid'),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                    childAspectRatio: 4 / 5.8,
                  ),
                  itemCount: drafts.length,
                  itemBuilder: (context, index) {
                    final draft = drafts[index];
                    return _DraftTile(
                      draft: draft,
                      onPressed: () => onSelected(draft),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({required this.draft, required this.onPressed});

  final StoryCardLocalDraftSummary draft;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('story-card-local-draft-${draft.id}'),
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  draft.previewImageBytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _savedAtLabel(draft.savedAt),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _savedAtLabel(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month.$day $hour:$minute';
  }
}
