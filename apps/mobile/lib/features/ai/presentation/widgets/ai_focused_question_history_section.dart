import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/ai_focused_question_history_entry.dart';

class AiFocusedQuestionHistorySection extends StatelessWidget {
  const AiFocusedQuestionHistorySection({super.key, required this.entries});

  final List<AiFocusedQuestionHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const Key('ai-focused-history'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WordBoundaryText('함께 답한 기록', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 8),
        for (var index = 0; index < entries.length; index++) ...[
          _FocusedQuestionHistoryRow(entry: entries[index]),
          if (index < entries.length - 1)
            const Divider(height: 1, color: AppColors.settingsDivider),
        ],
      ],
    );
  }
}

class _FocusedQuestionHistoryRow extends StatelessWidget {
  const _FocusedQuestionHistoryRow({required this.entry});

  final AiFocusedQuestionHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: Key('ai-focused-history-${entry.questionId}'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      iconColor: AppColors.textPrimary,
      collapsedIconColor: AppColors.textMuted,
      shape: const Border(),
      collapsedShape: const Border(),
      title: WordBoundaryText(
        entry.questionText,
        key: Key('ai-focused-history-question-${entry.questionId}'),
        style: AppTextStyles.homeBodyMedium,
      ),
      children: [
        _Answer(label: '내 답변', text: entry.myAnswerText),
        const SizedBox(height: 16),
        _Answer(label: '상대방 답변', text: entry.partnerAnswerText),
      ],
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          WordBoundaryText(text, style: AppTextStyles.homeBody),
        ],
      ),
    );
  }
}
