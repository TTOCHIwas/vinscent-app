import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../application/ai_question_feedback_provider.dart';
import '../../data/ai_learning_dashboard.dart';
import 'ai_character_speech_row.dart';

enum AiQuestionFeedbackPresentation { labeledText, characterSpeech }

class AiQuestionFeedbackSection extends ConsumerWidget {
  const AiQuestionFeedbackSection({
    super.key,
    required this.dailyQuestionId,
    this.presentation = AiQuestionFeedbackPresentation.labeledText,
  });

  final String dailyQuestionId;
  final AiQuestionFeedbackPresentation presentation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(aiQuestionFeedbackProvider(dailyQuestionId));

    return feedback.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (state) => switch (state) {
        AiQuestionFeedbackPublished(feedback: final feedback) =>
          _PublishedFeedback(feedback: feedback, presentation: presentation),
        AiQuestionFeedbackProcessing() =>
          presentation == AiQuestionFeedbackPresentation.characterSpeech
              ? const _FeedbackStatus(message: '둘이 남긴 답을 읽고 있어. 잠깐만 기다려줘!')
              : const SizedBox.shrink(),
        AiQuestionFeedbackDelayed() =>
          presentation == AiQuestionFeedbackPresentation.characterSpeech
              ? const _FeedbackStatus(message: '조금만 더 기다려줘. 다 읽으면 바로 알려줄게!')
              : const SizedBox.shrink(),
        AiQuestionFeedbackDisabled() => const SizedBox.shrink(),
      },
    );
  }
}

class _PublishedFeedback extends StatelessWidget {
  const _PublishedFeedback({
    required this.feedback,
    required this.presentation,
  });

  final AiQuestionFeedback feedback;
  final AiQuestionFeedbackPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('ai-question-feedback'),
      child: switch (presentation) {
        AiQuestionFeedbackPresentation.labeledText => _LabeledFeedback(
          feedback: feedback,
        ),
        AiQuestionFeedbackPresentation.characterSpeech =>
          _CharacterSpeechFeedback(feedback: feedback),
      },
    );
  }
}

class _LabeledFeedback extends StatelessWidget {
  const _LabeledFeedback({required this.feedback});

  final AiQuestionFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          WordBoundaryText(
            feedback.feedbackText,
            style: AppTextStyles.homeBodyMedium.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _CharacterSpeechFeedback extends StatelessWidget {
  const _CharacterSpeechFeedback({required this.feedback});

  final AiQuestionFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: AiCharacterSpeechRow(
        characterKey: const Key('ai-question-feedback-character'),
        bubbleKey: const Key('ai-question-feedback-prompt'),
        speechText: feedback.feedbackText,
        semanticLabel: '캐릭터의 한마디: ${feedback.feedbackText}',
        maxLines: 4,
      ),
    );
  }
}

class _FeedbackStatus extends StatelessWidget {
  const _FeedbackStatus({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('ai-question-feedback-status'),
      child: Padding(
        padding: const EdgeInsets.only(top: 32),
        child: AiCharacterThinkingSpeechRow(
          characterKey: const Key('ai-question-feedback-status-character'),
          bubbleKey: const Key('ai-question-feedback-status-prompt'),
          thinkingDotsKey: const Key('ai-question-feedback-thinking-dots'),
          message: message,
        ),
      ),
    );
  }
}
