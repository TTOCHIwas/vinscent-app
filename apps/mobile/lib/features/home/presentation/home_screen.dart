import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date/today_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../../questions/application/today_question_controller.dart';
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
                const Text('오늘의 질문', style: AppTextStyles.homeBodyMedium),
                const SizedBox(height: 8),
                todayQuestion.when(
                  loading: () => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (error, stackTrace) => Column(
                    children: [
                      Text(
                        '질문을 불러오지 못했어요',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.homeCharacterLabel.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(todayQuestionControllerProvider.notifier)
                            .refresh(),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                  data: (question) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      question?.questionText ?? '준비 중',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.homeCharacterLabel,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Container(
                  width: 140,
                  height: 140,
                  color: AppColors.wireframePlaceholder,
                  alignment: Alignment.center,
                  child: const Text(
                    '캐릭터 준비 중',
                    style: AppTextStyles.homeCharacterLabel,
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
