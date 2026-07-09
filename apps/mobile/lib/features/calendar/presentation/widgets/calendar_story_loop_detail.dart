import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../expressions/data/couple_expression.dart';
import '../../../expressions/data/couple_expression_summary.dart';
import '../../../questions/data/daily_question.dart';
import '../../../questions/data/daily_question_answer_state.dart';
import '../../../questions/presentation/question_route_context.dart';
import '../../../questions/presentation/widgets/character_speech_prompt.dart';
import '../../../questions/presentation/widgets/question_answer_sections.dart';
import '../../../story_loops/data/story_loop_detail.dart';
import '../../../story_loops/data/story_loop_detail_state.dart';
import 'calendar_story_card_stack.dart';

class CalendarStoryLoopDetail extends StatelessWidget {
  const CalendarStoryLoopDetail({
    super.key,
    required this.storyLoopState,
    required this.expressionSummaries,
  });

  final StoryLoopDetailState storyLoopState;
  final List<CoupleExpressionSummary> expressionSummaries;

  @override
  Widget build(BuildContext context) {
    return switch (storyLoopState) {
      LoadedStoryLoopDetailState(detail: final detail) => _LoadedDetailSection(
        detail: detail,
        expressionSummaries: expressionSummaries,
      ),
      EmptyStoryLoopDetailState(targetDate: final targetDate) =>
        _EmptyDetailSection(
          targetDate: targetDate,
          expressionSummaries: expressionSummaries,
        ),
      UnavailableStoryLoopDetailState(
        targetDate: final targetDate,
        reason: final reason,
      ) =>
        _UnavailableDetailSection(
          targetDate: targetDate,
          reason: reason,
          expressionSummaries: expressionSummaries,
        ),
    };
  }
}

class _LoadedDetailSection extends StatelessWidget {
  const _LoadedDetailSection({
    required this.detail,
    required this.expressionSummaries,
  });

  final StoryLoopDetail detail;
  final List<CoupleExpressionSummary> expressionSummaries;

  @override
  Widget build(BuildContext context) {
    final question = detail.question;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatFullDate(detail.coupleDate), style: _dateTitleStyle),
        if (detail.cards.isNotEmpty) ...[
          const SizedBox(height: 20),
          CalendarStoryCardStack(cards: detail.cards),
        ],
        if (question == null) ...[
          const SizedBox(height: 32),
          _CardOnlyMessage(detail: detail),
        ] else ...[
          const SizedBox(height: 10),
          _QuestionHistorySection(questionText: question.question.questionText),
          MyQuestionAnswerSection(
            answerState: question.answerState,
            displayStyle: QuestionAnswerDisplayStyle.plain,
            onPressed: _buildQuestionPressed(
              context: context,
              detail: detail,
              answerState: question.answerState,
            ),
          ),
          PartnerQuestionAnswerSection(
            answerState: question.answerState,
            hiddenMessage: PartnerQuestionAnswerSection.historyHiddenMessage,
            displayStyle: QuestionAnswerDisplayStyle.plain,
          ),
          const _SummaryPlaceholder(),
          if (question.answerState.status == DailyQuestionStatus.completed)
            const _AiCommentPlaceholder(),
        ],
        _ExpressionSummarySection(summaries: expressionSummaries),
      ],
    );
  }

  VoidCallback? _buildQuestionPressed({
    required BuildContext context,
    required StoryLoopDetail detail,
    required DailyQuestionAnswerState? answerState,
  }) {
    if (!detail.canAnswerQuestion) {
      return null;
    }

    final routeContext = QuestionRouteContext(
      source: QuestionRouteSource.calendar,
      targetDate: detail.coupleDate,
    );
    final targetLocation = (answerState?.hasMyAnswer ?? false)
        ? routeContext.buildQuestionLocation()
        : routeContext.buildEditLocation();
    return () => context.go(targetLocation);
  }
}

class _EmptyDetailSection extends StatelessWidget {
  const _EmptyDetailSection({
    required this.targetDate,
    required this.expressionSummaries,
  });

  final DateTime targetDate;
  final List<CoupleExpressionSummary> expressionSummaries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatFullDate(targetDate), style: _dateTitleStyle),
        const SizedBox(height: 32),
        const _StateMessage(
          title: '이 날의 질문 기록이 없어요',
          message: '질문이 생성된 날짜를 선택하면 기록을 볼 수 있어요',
        ),
        const SizedBox(height: 20),
        _ExpressionSummarySection(summaries: expressionSummaries),
      ],
    );
  }
}

class _UnavailableDetailSection extends StatelessWidget {
  const _UnavailableDetailSection({
    required this.targetDate,
    required this.reason,
    required this.expressionSummaries,
  });

  final DateTime targetDate;
  final StoryLoopDetailUnavailableReason reason;
  final List<CoupleExpressionSummary> expressionSummaries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatFullDate(targetDate), style: _dateTitleStyle),
        const SizedBox(height: 32),
        _StateMessage(
          title: switch (reason) {
            StoryLoopDetailUnavailableReason.unavailable => '기록을 확인할 수 없어요',
            StoryLoopDetailUnavailableReason.beforeRelationshipStartDate =>
              '아직 기록이 없어요',
            StoryLoopDetailUnavailableReason.futureDate => '아직 열리지 않은 날짜예요',
          },
          message: switch (reason) {
            StoryLoopDetailUnavailableReason.unavailable =>
              '커플 연결과 시작일을 먼저 확인해 주세요',
            StoryLoopDetailUnavailableReason.beforeRelationshipStartDate =>
              '관계 시작일 이후의 기록만 확인할 수 있어요',
            StoryLoopDetailUnavailableReason.futureDate =>
              '오늘 이후 날짜의 기록은 아직 볼 수 없어요',
          },
        ),
        const SizedBox(height: 20),
        _ExpressionSummarySection(summaries: expressionSummaries),
      ],
    );
  }
}

class _CardOnlyMessage extends StatelessWidget {
  const _CardOnlyMessage({required this.detail});

  final StoryLoopDetail detail;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      title: switch (detail.cardCount) {
        0 => '이 날의 질문 기록이 없어요',
        1 => '스토리 카드가 먼저 도착했어요',
        _ => '스토리 카드가 모두 모였어요',
      },
      message: switch (detail.cardCount) {
        0 => '질문이 생성된 날짜를 선택하면 기록을 볼 수 있어요',
        1 => '두 사람의 카드가 모두 올라오면 질문이 생성돼요',
        _ => '질문이 준비되면 이 자리에서 함께 볼 수 있어요',
      },
    );
  }
}

class _QuestionHistorySection extends StatelessWidget {
  const _QuestionHistorySection({required this.questionText});

  final String questionText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: double.infinity),
          Text(
            '그 날의 질문',
            textAlign: TextAlign.center,
            style: AppTextStyles.homeBody.copyWith(fontSize: 18, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            questionText,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeBody.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SummaryPlaceholder extends StatelessWidget {
  const _SummaryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('종합', style: AppTextStyles.homeBodyMedium),
          SizedBox(height: 4),
          Text(
            '아직 종합 기록이 없어요',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiCommentPlaceholder extends StatelessWidget {
  const _AiCommentPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: CharacterSpeechPrompt(
        labelText: 'AI 한 줄 평',
        speechText: '아직 AI 한 줄 평이 없어요',
      ),
    );
  }
}

class _ExpressionSummarySection extends StatelessWidget {
  const _ExpressionSummarySection({required this.summaries});

  static const _types = [
    CoupleExpressionType.missYou,
    CoupleExpressionType.thanks,
    CoupleExpressionType.feelingDown,
    CoupleExpressionType.cheerUp,
  ];

  final List<CoupleExpressionSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('그 날의 표현 횟수', style: AppTextStyles.homeCharacterLabel),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ExpressionSummaryPill(
                  type: _types[0],
                  sentCount: _sentCountFor(_types[0]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ExpressionSummaryPill(
                  type: _types[1],
                  sentCount: _sentCountFor(_types[1]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ExpressionSummaryPill(
                  type: _types[2],
                  sentCount: _sentCountFor(_types[2]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ExpressionSummaryPill(
                  type: _types[3],
                  sentCount: _sentCountFor(_types[3]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _sentCountFor(CoupleExpressionType type) {
    for (final summary in summaries) {
      if (summary.type == type) {
        return summary.sentCount;
      }
    }

    return 0;
  }
}

class _ExpressionSummaryPill extends StatelessWidget {
  const _ExpressionSummaryPill({required this.type, required this.sentCount});

  final CoupleExpressionType type;
  final int sentCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF838384)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _expressionIconFor(type),
            size: 18,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              type.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$sentCount',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeBodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _expressionIconFor(CoupleExpressionType type) {
  return switch (type) {
    CoupleExpressionType.missYou => Icons.favorite_border,
    CoupleExpressionType.thanks => Icons.thumb_up_alt_outlined,
    CoupleExpressionType.feelingDown => Icons.sentiment_dissatisfied_outlined,
    CoupleExpressionType.cheerUp => Icons.wb_sunny_outlined,
  };
}

String _formatFullDate(DateTime date) {
  final year = date.year;
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year년 $month월 $day일';
}

final _dateTitleStyle = AppTextStyles.homeBody.copyWith(
  fontSize: 16,
  height: 1.4,
);
