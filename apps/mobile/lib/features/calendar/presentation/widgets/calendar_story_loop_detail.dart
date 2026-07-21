import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../ai/presentation/widgets/ai_question_feedback_section.dart';
import '../../../questions/data/daily_question_answer_state.dart';
import '../../../questions/presentation/question_route_context.dart';
import '../../../questions/presentation/widgets/question_answer_prompt_row.dart';
import '../../../questions/presentation/widgets/question_answer_sections.dart';
import '../../../story_loops/data/story_loop_detail.dart';
import '../../../story_loops/data/story_loop_detail_state.dart';
import '../../../story_loops/presentation/widgets/story_card_detail_overlay.dart';
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
        _DetailDateHeader(date: detail.coupleDate),
        if (detail.cards.isNotEmpty) ...[
          const SizedBox(height: 24),
          CalendarStoryCardStack(
            cards: detail.cards,
            currentUserId: currentUserId,
            onCardTap: (card) => showStoryCardDetailOverlay(
              context: context,
              cardId: card.id,
              previewUrl: card.previewUrl,
            ),
          ),
        ],
        if (question == null) ...[
          const SizedBox(height: 32),
          _CardOnlyMessage(detail: detail),
        ] else ...[
          const SizedBox(height: 28),
          QuestionAnswerPromptRow(questionText: question.question.questionText),
          const SizedBox(height: 24),
          QuestionAnswerOverview(
            answerState: question.answerState,
            partnerHiddenMessage:
                PartnerQuestionAnswerSection.historyHiddenMessage,
            onMyAnswerPressed: _buildQuestionPressed(
              context: context,
              detail: detail,
              answerState: question.answerState,
            ),
          ),
          if (question.answerState.hasBothAnswers)
            AiQuestionFeedbackSection(
              dailyQuestionId: question.question.dailyQuestionId,
            ),
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
        _DetailDateHeader(date: targetDate),
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
        _DetailDateHeader(date: targetDate),
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

class _DetailDateHeader extends StatelessWidget {
  const _DetailDateHeader({required this.date});

  static const _weekdayLabels = [
    '월요일',
    '화요일',
    '수요일',
    '목요일',
    '금요일',
    '토요일',
    '일요일',
  ];

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${date.month}월 ${date.day}일',
          style: AppTextStyles.shellDayCount.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${date.year} · ${_weekdayLabels[date.weekday - 1]}',
          style: AppTextStyles.homeCharacterLabel.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
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
