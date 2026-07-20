import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/ai_question_feedback_provider.dart';
import '../../data/ai_learning_dashboard.dart';

class AiQuestionFeedbackSection extends ConsumerWidget {
  const AiQuestionFeedbackSection({super.key, required this.dailyQuestionId});

  final String dailyQuestionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(aiQuestionFeedbackProvider(dailyQuestionId));

    return feedback.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (value) => switch (value) {
        final AiQuestionFeedback feedback => _PublishedFeedback(
          feedback: feedback,
        ),
        null => const SizedBox.shrink(),
      },
    );
  }
}

class _PublishedFeedback extends StatelessWidget {
  const _PublishedFeedback({required this.feedback});

  final AiQuestionFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('ai-question-feedback'),
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.settingsDivider),
          const SizedBox(height: 20),
          Text(
            'AI의 한마디',
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feedback.feedbackText,
            style: AppTextStyles.homeBodyMedium.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}
