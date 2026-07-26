import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_story_card_stack.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_prompt_row.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_sections.dart';
import 'package:vinscent/features/story_loops/data/story_loop_status.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_preview_surface.dart';

import '../../../support/story_loop_fixtures.dart';
import '../../../support/text_finders.dart';
import 'calendar_screen_test_support.dart';

void main() {
  testWidgets('fetches selected past date and shows story loop detail', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): completedDetail},
    );
    await pumpCalendar(
      tester,
      repository: repository,
      aiFeedbacks: {
        'daily-question-id': AiQuestionFeedback(
          dailyQuestionId: 'daily-question-id',
          feedbackText: '둘 다 소중한 대상을 바로 떠올렸네',
          publishedAt: DateTime.utc(2026, 5, 5, 12),
        ),
      },
    );

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 5),
    ]);
    expect(find.text('5월 5일'), findsOneWidget);
    expect(find.text('2026 · 화요일'), findsOneWidget);
    final cardStack = find.byType(CalendarStoryCardStack);
    expect(cardStack, findsOneWidget);
    expect(
      find.descendant(
        of: cardStack,
        matching: find.byType(StoryCardPreviewSurface),
      ),
      findsNWidgets(2),
    );
    expect(framedDecorations(tester, cardStack), hasLength(2));
    final myCard = find.byKey(const ValueKey('calendar-story-card-card-2'));
    final partnerCard = find.byKey(
      const ValueKey('calendar-story-card-card-1'),
    );
    expect(myCard, findsOneWidget);
    expect(partnerCard, findsOneWidget);
    final myCardRect = tester.getRect(myCard);
    final partnerCardRect = tester.getRect(partnerCard);
    expect(myCardRect.right, lessThanOrEqualTo(partnerCardRect.left));
    expect(myCardRect.top, partnerCardRect.top);
    expect(
      find.descendant(of: cardStack, matching: find.byType(Transform)),
      findsNothing,
    );
    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(find.byIcon(Icons.brush_outlined), findsNothing);
    expect(find.byIcon(Icons.text_fields), findsNothing);
    expect(
      circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-05'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );
    expect(find.text('history question'), findsOneWidget);
    expect(find.byKey(const Key('question-detail-title')), findsOneWidget);
    expect(find.byType(QuestionAnswerPromptRow), findsNothing);
    expect(find.byType(QuestionAnswerOverview), findsOneWidget);
    expect(find.text('my answer'), findsOneWidget);
    expect(find.text('partner answer'), findsOneWidget);
    expect(find.text('종합'), findsNothing);
    expect(find.text('AI의 한마디'), findsNothing);
    expect(
      find.byKey(const Key('ai-question-feedback-character')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ai-question-feedback-prompt')),
      findsOneWidget,
    );
    expect(findTextIgnoringWordJoiners('둘 다 소중한 대상을 바로 떠올렸네'), findsOneWidget);
    expect(find.text('그 날의 표현 횟수'), findsNothing);
  });

  testWidgets('opens a selected history card in the shared detail overlay', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): completedDetail},
    );
    await pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('calendar-story-card-card-2'));
    await scrollCalendarUp(tester);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-card-detail-overlay')), findsOneWidget);
    expect(find.byKey(const Key('story-card-detail-card-2')), findsOneWidget);
  });

  testWidgets('shows card only detail when question has not been generated', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): cardOnlyDetail},
    );

    await pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 5),
    ]);
    expect(find.byType(CalendarStoryCardStack), findsOneWidget);
    expect(find.text('스토리 카드가 먼저 도착했어요'), findsOneWidget);
    expect(find.text('두 사람의 카드가 모두 올라오면 질문이 생성돼요'), findsOneWidget);
    expect(find.text('history question'), findsNothing);
    expect(find.text('09:00'), findsNothing);
  });

  testWidgets('shows a distinct message while an AI question is preparing', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {
        DateTime(2026, 5, 5): twoCardDetail(StoryLoopStatus.questionPreparing),
      },
    );

    await pumpCalendar(tester, repository: repository);
    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('둘의 카드가 모두 모였어요'), findsOneWidget);
    expect(find.text('둘에게 어울릴 질문을 고르고 있어요'), findsOneWidget);
  });

  testWidgets('does not promise a question for a card-only date', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {
        DateTime(2026, 5, 5): twoCardDetail(StoryLoopStatus.cardOnlyCompleted),
      },
    );

    await pumpCalendar(tester, repository: repository);
    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('이 날은 카드만 남겼어요'), findsOneWidget);
    expect(find.text('두 사람이 남긴 카드를 그대로 간직할 수 있어요'), findsOneWidget);
    expect(find.text('질문이 준비되면 이 자리에서 함께 볼 수 있어요'), findsNothing);
  });

  testWidgets('shows empty state when selected date has no loop', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 5),
    ]);
    expect(find.text('이 날의 질문 기록이 없어요'), findsOneWidget);
    expect(find.text('그 날의 표현 횟수'), findsNothing);
  });

  testWidgets('retries selected past date after detail load failure', (
    tester,
  ) async {
    final repository = FlakyStoryLoopReadRepository(entry: completedDetail);

    await pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 5),
    ]);
    expect(find.text('기록을 불러오지 못했어요'), findsOneWidget);

    await scrollCalendarUp(tester);
    await tester.tap(find.byKey(const Key('calendar-story-detail-retry')));
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 5),
      DateTime(2026, 5, 5),
    ]);
    expect(find.text('history question'), findsOneWidget);
  });

  testWidgets('uses history hidden copy when my answer is missing', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): partnerOnlyDetail},
    );

    await pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('내 답변이 없어 상대방 답변을 확인할 수 없어요'), findsOneWidget);
    expect(find.text('partner answer'), findsNothing);
    expect(find.text('AI 한 줄 평'), findsNothing);
    expect(find.text('아직 AI 한 줄 평이 없어요'), findsNothing);
  });

  testWidgets('selects today without leaving calendar', (tester) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 10): todayPendingDetail},
    );

    await pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
    expect(find.text('calendar question route'), findsNothing);
    expect(find.text('today history question'), findsOneWidget);
  });

  testWidgets('opens edit flow for today when my answer is missing', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 10): todayPendingDetail},
    );

    await pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('내 답변'));
    await scrollCalendarUp(tester);
    await tester.tap(find.text('내 답변'));
    await tester.pumpAndSettle();

    expect(find.text('calendar question edit route'), findsOneWidget);
  });
}
