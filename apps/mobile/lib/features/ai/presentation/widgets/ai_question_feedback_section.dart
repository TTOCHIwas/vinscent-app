import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../characters/presentation/widgets/couple_character_avatar.dart';
import '../../../../core/presentation/widgets/character_speech_bubble.dart';
import '../../application/ai_question_feedback_provider.dart';
import '../../data/ai_learning_dashboard.dart';

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
      data: (value) => switch (value) {
        final AiQuestionFeedback feedback => _PublishedFeedback(
          feedback: feedback,
          presentation: presentation,
        ),
        null => const SizedBox.shrink(),
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
          Text(
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

  static const _characterSize = 96.0;
  static const _maximumContentWidth = 360.0;

  final AiQuestionFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maximumContentWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CoupleCharacterAvatar(
                key: Key('ai-question-feedback-character'),
                size: _characterSize,
              ),
              Flexible(
                fit: FlexFit.loose,
                child: Semantics(
                  label: '캐릭터의 한마디: ${feedback.feedbackText}',
                  excludeSemantics: true,
                  child: CharacterSpeechBubble(
                    key: const Key('ai-question-feedback-prompt'),
                    speechText: feedback.feedbackText,
                    maxWidth: double.infinity,
                    maxLines: 4,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    tailSize: const Size(10, 18),
                    tailPosition: SpeechBubbleTailPosition.left,
                    textStyle: AppTextStyles.homeQuestionBubble,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
