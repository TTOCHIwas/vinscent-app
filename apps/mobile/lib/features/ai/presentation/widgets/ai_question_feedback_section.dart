import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
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
    return _CharacterFeedbackRow(
      characterKey: const Key('ai-question-feedback-character'),
      bubble: Semantics(
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
      child: _CharacterFeedbackRow(
        characterKey: const Key('ai-question-feedback-status-character'),
        bubble: CharacterSpeechBubble.custom(
          key: const Key('ai-question-feedback-status-prompt'),
          semanticLabel: message,
          maxWidth: double.infinity,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          tailSize: const Size(10, 18),
          tailPosition: SpeechBubbleTailPosition.left,
          child: _FeedbackStatusContent(message: message),
        ),
      ),
    );
  }
}

class _CharacterFeedbackRow extends StatelessWidget {
  const _CharacterFeedbackRow({
    required this.characterKey,
    required this.bubble,
  });

  static const _characterSize = 96.0;
  static const _maximumContentWidth = 360.0;

  final Key characterKey;
  final Widget bubble;

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
              CoupleCharacterAvatar(key: characterKey, size: _characterSize),
              Flexible(fit: FlexFit.loose, child: bubble),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackStatusContent extends StatelessWidget {
  const _FeedbackStatusContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        WordBoundaryText(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.homeQuestionBubble,
        ),
        const _ThinkingDots(),
      ],
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  static const _dotCount = 3;
  static const _dotSize = 5.0;
  static const _duration = Duration(milliseconds: 1100);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('ai-question-feedback-thinking-dots'),
      width: 25,
      height: 12,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_dotCount, (index) {
              final phase = (_controller.value - (index * 0.18)) % 1.0;
              final strength = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
              return Transform.translate(
                offset: Offset(0, -2 * strength),
                child: Opacity(
                  opacity: 0.3 + (0.7 * strength),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: _dotSize),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
