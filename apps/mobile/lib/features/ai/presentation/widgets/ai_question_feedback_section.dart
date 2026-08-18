import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../safety/data/safety_report.dart';
import '../../../safety/presentation/safety_report_sheet.dart';
import '../../application/ai_question_feedback_provider.dart';
import '../../data/ai_learning_dashboard.dart';
import 'ai_character_speech_row.dart';
import 'ai_generated_content_indicator.dart';

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
          _PublishedFeedback(
            dailyQuestionId: dailyQuestionId,
            feedback: feedback,
            presentation: presentation,
          ),
        AiQuestionFeedbackProcessing() =>
          presentation == AiQuestionFeedbackPresentation.characterSpeech
              ? const _FeedbackStatus(message: '둘이 남긴 답을 읽고 있어. 잠깐만 기다려줘!')
              : const SizedBox.shrink(),
        AiQuestionFeedbackDelayed() =>
          presentation == AiQuestionFeedbackPresentation.characterSpeech
              ? const _FeedbackStatus(message: '조금만 더 기다려줘. 다 읽으면 바로 알려줄게!')
              : const SizedBox.shrink(),
        AiQuestionFeedbackFailed() =>
          presentation == AiQuestionFeedbackPresentation.characterSpeech
              ? const _FeedbackFailure()
              : const SizedBox.shrink(),
        AiQuestionFeedbackDisabled() => const SizedBox.shrink(),
      },
    );
  }
}

class _PublishedFeedback extends StatelessWidget {
  const _PublishedFeedback({
    required this.dailyQuestionId,
    required this.feedback,
    required this.presentation,
  });

  final String dailyQuestionId;
  final AiQuestionFeedback feedback;
  final AiQuestionFeedbackPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('ai-question-feedback'),
      child: switch (presentation) {
        AiQuestionFeedbackPresentation.labeledText => _LabeledFeedback(
          dailyQuestionId: dailyQuestionId,
          feedback: feedback,
        ),
        AiQuestionFeedbackPresentation.characterSpeech =>
          _CharacterSpeechFeedback(
            dailyQuestionId: dailyQuestionId,
            feedback: feedback,
          ),
      },
    );
  }
}

class _LabeledFeedback extends StatelessWidget {
  const _LabeledFeedback({
    required this.dailyQuestionId,
    required this.feedback,
  });

  final String dailyQuestionId;
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
          Row(
            children: [
              Text(
                'AI의 한마디',
                style: AppTextStyles.homeCharacterLabel.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              AiGeneratedContentIndicator(
                onReportPressed: () => _showFeedbackReport(
                  context,
                  dailyQuestionId: dailyQuestionId,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          WordBoundaryText(
            feedback.feedbackText,
            style: AppTextStyles.homeBodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CharacterSpeechFeedback extends StatelessWidget {
  const _CharacterSpeechFeedback({
    required this.dailyQuestionId,
    required this.feedback,
  });

  final String dailyQuestionId;
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
        characterSize: 96,
        maximumContentWidth: 360,
        showGeneratedAttribution: true,
        onGeneratedAttributionPressed: () =>
            _showFeedbackReport(context, dailyQuestionId: dailyQuestionId),
      ),
    );
  }
}

void _showFeedbackReport(
  BuildContext context, {
  required String dailyQuestionId,
}) {
  showSafetyReportSheet(
    context: context,
    target: SafetyReportTarget(
      type: SafetyReportTargetType.aiFeedback,
      id: dailyQuestionId,
    ),
  );
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
          characterSize: 96,
          maximumContentWidth: 360,
        ),
      ),
    );
  }
}

class _FeedbackFailure extends StatelessWidget {
  const _FeedbackFailure();

  static const _message = '이번 한마디는 잘 떠오르지 않았어...';

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: Key('ai-question-feedback-failed'),
      child: Padding(
        padding: EdgeInsets.only(top: 32),
        child: AiCharacterSpeechRow(
          characterKey: Key('ai-question-feedback-failed-character'),
          bubbleKey: Key('ai-question-feedback-failed-prompt'),
          speechText: _message,
          semanticLabel: '캐릭터의 한마디: $_message',
          characterSize: 96,
          maximumContentWidth: 360,
        ),
      ),
    );
  }
}
