import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../../expressions/application/couple_expression_controller.dart';
import '../../expressions/data/couple_expression.dart';
import '../../questions/application/question_detail_provider.dart';
import '../../questions/data/daily_question.dart';
import '../../questions/data/question_detail_state.dart';
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

            if (!couple.hasRelationshipStartDate) {
              return Text(
                couple.isArchivedReadOnly
                    ? '기록 보관 중이에요'
                    : '첫 만난 날을 먼저 입력해주세요.',
                textAlign: TextAlign.end,
                style: AppTextStyles.homeBody.copyWith(
                  color: AppColors.textMuted,
                ),
              );
            }

            final dayCount = calculateRelationshipDayCount(
              startDate: couple.relationshipStartDate!,
              today: couple.effectiveCurrentDate,
            );
            final headline = couple.isArchivedReadOnly ? '기록 보관 중' : '우리';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(headline, style: AppTextStyles.homeBody),
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
                      TextSpan(
                        text: couple.isArchivedReadOnly ? ' 보관 중' : '일째',
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
    final coupleAsync = ref.watch(coupleControllerProvider);

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: coupleAsync.when(
          loading: () => const _HomeQuestionSpeechPrompt(
            speechText: '홈 화면을 준비하고 있어요.',
            footer: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, stackTrace) => _HomeQuestionSpeechPrompt(
            speechText: '질문 화면을 열지 못했어요.',
            footer: TextButton(
              onPressed: () =>
                  ref.read(coupleControllerProvider.notifier).refresh(),
              child: const Text('다시 시도'),
            ),
          ),
          data: (couple) {
            if (couple == null) {
              return const _HomeQuestionSpeechPrompt(
                speechText: '커플 연결을 먼저 완료해주세요.',
              );
            }

            if (couple.isArchivedReadOnly) {
              return _HomeQuestionSpeechPrompt(
                speechText: '연결은 해제되었지만 지난 기록은 30일 동안 읽기 전용으로 볼 수 있어요.',
                onCharacterTap: () => context.go('/home/character'),
              );
            }

            final detail = ref.watch(questionDetailProvider(null));
            return detail.when(
              loading: () => const _HomeQuestionSpeechPrompt(
                speechText: '오늘 질문을 불러오고 있어요.',
                footer: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, stackTrace) => _HomeQuestionSpeechPrompt(
                speechText: '오늘 질문을 불러오지 못했어요.',
                footer: TextButton(
                  onPressed: () => ref.invalidate(questionDetailProvider(null)),
                  child: const Text('다시 시도'),
                ),
                onCharacterTap: () => context.go('/home/character'),
              ),
              data: (state) {
                return switch (state) {
                  LoadedQuestionDetailState() => _ActiveQuestionPreview(
                    state: state,
                  ),
                  UnavailableQuestionDetailState() => _HomeQuestionSpeechPrompt(
                    speechText: '오늘 질문이 아직 준비되지 않았어요.',
                    onCharacterTap: () => context.go('/home/character'),
                  ),
                };
              },
            );
          },
        ),
      ),
    );
  }
}

class _ActiveQuestionPreview extends StatelessWidget {
  const _ActiveQuestionPreview({required this.state});

  final LoadedQuestionDetailState state;

  @override
  Widget build(BuildContext context) {
    final answerState = state.answerState;
    final hasMyAnswer = answerState?.hasMyAnswer ?? false;
    final hasPartnerAnswer = answerState?.partnerAnswerExists ?? false;
    final isCompleted = answerState?.status == DailyQuestionStatus.completed;

    String speechText;
    if (isCompleted) {
      speechText = 'AI 한 줄 평이 여기에 표시될 예정이에요.';
    } else if (!hasMyAnswer && hasPartnerAnswer) {
      speechText = '상대방은 답변을 남겼어요.';
    } else if (hasMyAnswer) {
      speechText = '상대방의 답변을 기다리고 있어요.';
    } else {
      speechText = state.question.questionText;
    }

    final targetLocation = hasMyAnswer ? '/home/question' : '/home/question/edit';

    return _HomeQuestionSpeechPrompt(
      speechText: speechText,
      onSpeechTap: () => context.go(targetLocation),
      onCharacterTap: () => context.go('/home/character'),
    );
  }
}

class _HomeQuestionSpeechPrompt extends StatelessWidget {
  const _HomeQuestionSpeechPrompt({
    required this.speechText,
    this.footer,
    this.onSpeechTap,
    this.onCharacterTap,
  });

  final String speechText;
  final Widget? footer;
  final VoidCallback? onSpeechTap;
  final VoidCallback? onCharacterTap;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;

    return Column(
      children: [
        CharacterSpeechPrompt(
          labelText: '오늘의 질문',
          speechText: speechText,
          onSpeechTap: onSpeechTap,
          onCharacterTap: onCharacterTap,
        ),
        if (footer != null) ...[const SizedBox(height: 12), footer],
      ],
    );
  }
}

class _ExpressionGrid extends ConsumerWidget {
  const _ExpressionGrid();

  static const _actions = [
    _ExpressionAction(
      type: CoupleExpressionType.missYou,
      icon: Icons.favorite_border,
    ),
    _ExpressionAction(
      type: CoupleExpressionType.thanks,
      icon: Icons.thumb_up_alt_outlined,
    ),
    _ExpressionAction(
      type: CoupleExpressionType.feelingDown,
      icon: Icons.sentiment_dissatisfied_outlined,
    ),
    _ExpressionAction(
      type: CoupleExpressionType.cheerUp,
      icon: Icons.wb_sunny_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expressionState = ref.watch(coupleExpressionControllerProvider);
    final couple = ref.watch(
      coupleControllerProvider.select(
        (state) => state.maybeWhen(data: (value) => value, orElse: () => null),
      ),
    );
    final isSending = expressionState.isLoading;
    final canSend = (couple?.canEditSharedData ?? false) && !isSending;

    return Column(
      children: [
        if (couple?.isArchivedReadOnly == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '보관 중에는 표현 보내기가 잠시 닫혀 있어요.',
              style: AppTextStyles.homeCharacterLabel.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _ExpressionButton(
                action: _actions[0],
                isEnabled: canSend,
                onTap: () => _sendExpression(context, ref, _actions[0].type),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExpressionButton(
                action: _actions[1],
                isEnabled: canSend,
                onTap: () => _sendExpression(context, ref, _actions[1].type),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ExpressionButton(
                action: _actions[2],
                isEnabled: canSend,
                onTap: () => _sendExpression(context, ref, _actions[2].type),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExpressionButton(
                action: _actions[3],
                isEnabled: canSend,
                onTap: () => _sendExpression(context, ref, _actions[3].type),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _sendExpression(
    BuildContext context,
    WidgetRef ref,
    CoupleExpressionType type,
  ) async {
    try {
      await ref.read(coupleExpressionControllerProvider.notifier).send(type);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('표현을 보냈어요.')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('표현을 보내지 못했어요.')));
    }
  }
}

class _ExpressionAction {
  const _ExpressionAction({required this.type, required this.icon});

  final CoupleExpressionType type;
  final IconData icon;
}

class _ExpressionButton extends StatelessWidget {
  const _ExpressionButton({
    required this.action,
    required this.isEnabled,
    required this.onTap,
  });

  final _ExpressionAction action;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isEnabled
        ? AppColors.textPrimary
        : AppColors.actionDisabledContent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.wireframeBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 24, color: foreground),
              const SizedBox(width: 10),
              Text(
                action.type.label,
                style: AppTextStyles.homeBody.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
