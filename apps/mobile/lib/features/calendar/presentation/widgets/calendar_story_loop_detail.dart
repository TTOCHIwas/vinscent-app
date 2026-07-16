import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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
    this.currentUserId,
  });

  final StoryLoopDetailState storyLoopState;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return switch (storyLoopState) {
      LoadedStoryLoopDetailState(detail: final detail) => _LoadedDetailSection(
        detail: detail,
        currentUserId: currentUserId,
      ),
      EmptyStoryLoopDetailState(targetDate: final targetDate) =>
        _EmptyDetailSection(targetDate: targetDate),
      UnavailableStoryLoopDetailState(
        targetDate: final targetDate,
        reason: final reason,
      ) =>
        _UnavailableDetailSection(targetDate: targetDate, reason: reason),
    };
  }
}

class _LoadedDetailSection extends StatelessWidget {
  const _LoadedDetailSection({required this.detail, this.currentUserId});

  final StoryLoopDetail detail;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final question = detail.question;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatFullDate(detail.coupleDate), style: _dateTitleStyle),
        if (detail.cards.isNotEmpty) ...[
          const SizedBox(height: 20),
          CalendarStoryCardStack(
            cards: detail.cards,
            currentUserId: currentUserId,
          ),
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
  const _EmptyDetailSection({required this.targetDate});

  final DateTime targetDate;

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
      ],
    );
  }
}

class _UnavailableDetailSection extends StatelessWidget {
  const _UnavailableDetailSection({
    required this.targetDate,
    required this.reason,
  });

  final DateTime targetDate;
  final StoryLoopDetailUnavailableReason reason;

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
