import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date/today_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../../questions/application/today_question_controller.dart';
import '../../questions/presentation/widgets/character_speech_prompt.dart';
import '../application/day_count.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentMinHeight = (constraints.maxHeight - 64).clamp(
          0.0,
          double.infinity,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: contentMinHeight),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CoupleStatus(),
                  _QuestionCharacterPreview(),
                  _ExpressionGrid(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoupleStatus extends ConsumerWidget {
  const _CoupleStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(coupleControllerProvider);

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: couple.when(
          loading: () => const Align(
            alignment: Alignment.centerRight,
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, stackTrace) =>
              const _CoupleStatusMessage('커플 정보를 불러오지 못했어요.'),
          data: (couple) {
            if (couple == null) {
              return const _CoupleStatusMessage('커플 정보를 찾을 수 없어요.');
            }

            if (couple.status != CoupleStatus.active) {
              return const _CoupleStatusMessage('커플 연결을 완료해주세요.');
            }

            final relationshipStartDate = couple.relationshipStartDate;
            if (relationshipStartDate == null) {
              return const _CoupleStatusMessage('첫 만남일을 먼저 입력해주세요.');
            }

            final today = ref.watch(todayControllerProvider);
            final dayCount = calculateRelationshipDayCount(
              startDate: relationshipStartDate,
              today: today,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('우리 둘', style: AppTextStyles.homeBody),
                const SizedBox(height: 4),
                RichText(
                  textAlign: TextAlign.end,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'D+',
                        style: AppTextStyles.homeBodyMedium,
                      ),
                      TextSpan(
                        text: '$dayCount',
                        style: AppTextStyles.homeDayCount,
                      ),
                      const TextSpan(
                        text: '일',
                        style: AppTextStyles.homeBodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CoupleStatusMessage extends StatelessWidget {
  const _CoupleStatusMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        message,
        textAlign: TextAlign.end,
        style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}

class _QuestionCharacterPreview extends ConsumerWidget {
  const _QuestionCharacterPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayQuestion = ref.watch(todayQuestionControllerProvider);
    final canOpenQuestion = todayQuestion.when(
      loading: () => false,
      error: (error, stackTrace) => false,
      data: (question) => question != null,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canOpenQuestion ? () => context.go('/home/question') : null,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                todayQuestion.when(
                  loading: () => const _HomeQuestionSpeechPrompt(
                    speechText: '오늘 질문을 가져오고 있어요',
                    footer: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (error, stackTrace) => _HomeQuestionSpeechPrompt(
                    speechText: '질문을 불러오지 못했어요',
                    footer: TextButton(
                      onPressed: () => ref
                          .read(todayQuestionControllerProvider.notifier)
                          .refresh(),
                      child: const Text('다시 시도'),
                    ),
                  ),
                  data: (question) => _HomeQuestionSpeechPrompt(
                    speechText: question?.questionText ?? '오늘의 질문을 준비 중이에요',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeQuestionSpeechPrompt extends StatelessWidget {
  const _HomeQuestionSpeechPrompt({
    required this.speechText,
    this.footer,
  });

  final String speechText;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;

    return Column(
      children: [
        CharacterSpeechPrompt(
          labelText: '오늘의 질문',
          speechText: speechText,
        ),
        if (footer != null) ...[
          const SizedBox(height: 12),
          footer,
        ],
      ],
    );
  }
}

class _ExpressionGrid extends StatelessWidget {
  const _ExpressionGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: _ExpressionButton()),
            SizedBox(width: 8),
            Expanded(child: _ExpressionButton()),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _ExpressionButton()),
            SizedBox(width: 8),
            Expanded(child: _ExpressionButton()),
          ],
        ),
      ],
    );
  }
}

class _ExpressionButton extends StatelessWidget {
  const _ExpressionButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.wireframeBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.wireframeIcon),
                ),
              ),
              SizedBox(width: 10),
              Text('표현', style: AppTextStyles.homeBody),
            ],
          ),
        ),
      ),
    );
  }
}
