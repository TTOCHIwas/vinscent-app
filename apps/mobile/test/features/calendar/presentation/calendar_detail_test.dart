import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_story_card_stack.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_prompt_row.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_sections.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_detail_title.dart';
import 'package:vinscent/features/safety/data/safety_report.dart';
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
    final detailContent = find.byKey(
      const Key('calendar-story-detail-content'),
    );
    final detailContentRect = tester.getRect(detailContent);
    expect(myCardRect.left, closeTo(detailContentRect.left, 0.5));
    expect(partnerCardRect.right, closeTo(detailContentRect.right, 0.5));
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
    expect(find.byKey(const Key('calendar-schedule-section')), findsNothing);
    expect(find.byKey(const Key('calendar-story-section')), findsOneWidget);
    expect(find.text('우리 기록'), findsOneWidget);
    final scrollView = find.byKey(const Key('calendar-scroll-view'));
    expect(tester.getSize(detailContent).width, 520);
    expect(
      tester.getCenter(detailContent).dx,
      closeTo(tester.getCenter(scrollView).dx, 0.5),
    );
    final questionTitle = tester.widget<QuestionDetailTitle>(
      find.byType(QuestionDetailTitle),
    );
    expect(questionTitle.textAlign, TextAlign.start);
    final answerOverview = tester.widget<QuestionAnswerOverview>(
      find.byType(QuestionAnswerOverview),
    );
    expect(answerOverview.displayStyle, QuestionAnswerDisplayStyle.plain);
    expect(
      find.byKey(const Key('question-answer-grouped-surface')),
      findsNothing,
    );
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

  testWidgets('reports an AI-generated question from calendar detail', (
    tester,
  ) async {
    final safetyRepository = FakeSafetyReportRepository();
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): aiCompletedDetail},
    );
    await pumpCalendar(
      tester,
      repository: repository,
      safetyReportRepository: safetyRepository,
    );

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();
    await scrollCalendarUp(tester);
    await scrollCalendarUp(tester);
    final indicator = find.byKey(const Key('ai-generated-content-indicator'));
    await tester.ensureVisible(indicator);
    final questionTitle = find.byType(QuestionDetailTitle);
    final generatedBadge = find.byKey(const Key('ai-generated-content-badge'));
    final renderedQuestion = find.byKey(const Key('question-detail-title'));
    expect(
      tester.widget<QuestionDetailTitle>(questionTitle).textAlign,
      TextAlign.start,
    );
    expect(
      tester.getRect(generatedBadge).center.dx,
      greaterThan(tester.getRect(questionTitle).center.dx),
    );
    expect(
      tester.getRect(generatedBadge).top,
      greaterThanOrEqualTo(tester.getRect(renderedQuestion).bottom),
    );
    await tester.tap(indicator);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-generated-content-report')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-report-reason-unsafeAi')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('safety-report-submit')));
    await tester.tap(find.byKey(const Key('safety-report-submit')));
    await tester.pumpAndSettle();

    expect(
      safetyRepository.requests.single.target,
      const SafetyReportTarget(
        type: SafetyReportTargetType.aiQuestion,
        id: 'ai-daily-question-id',
      ),
    );
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

  testWidgets('separates schedules and shared records in date detail', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(
        details: {DateTime(2026, 5, 5): completedDetail},
      ),
      initialDate: DateTime(2026, 5, 5),
      calendarEvents: [
        calendarEvent(
          id: 'shared-event',
          title: '함께 보는 일정',
          date: DateTime(2026, 5, 5),
        ),
      ],
    );

    final scheduleSection = find.byKey(const Key('calendar-schedule-section'));
    final storySection = find.byKey(const Key('calendar-story-section'));

    expect(scheduleSection, findsOneWidget);
    expect(storySection, findsOneWidget);
    expect(
      find.descendant(of: scheduleSection, matching: find.text('일정')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: storySection, matching: find.text('우리 기록')),
      findsOneWidget,
    );
    expect(
      tester.getRect(scheduleSection).bottom,
      lessThan(tester.getRect(storySection).top),
    );
  });

  testWidgets('reports a partner-updated calendar event', (tester) async {
    final safetyRepository = FakeSafetyReportRepository();
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      initialDate: DateTime(2026, 5, 5),
      calendarEvents: [
        calendarEvent(
          id: 'partner-event',
          title: 'Partner event',
          date: DateTime(2026, 5, 5),
          createdByUserId: 'user-a',
          updatedByUserId: 'user-a',
        ),
      ],
      safetyReportRepository: safetyRepository,
    );

    final partnerEventMenu = find.byKey(
      const Key('calendar-event-menu-partner-event'),
    );
    await tester.ensureVisible(partnerEventMenu);
    await tester.pumpAndSettle();
    await tester.tap(partnerEventMenu);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-event-action-report-partner-event')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('calendar-event-action-report-partner-event')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('safety-report-reason-inappropriate')),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('safety-report-submit')));
    await tester.tap(find.byKey(const Key('safety-report-submit')));
    await tester.pumpAndSettle();

    expect(
      safetyRepository.requests.single.target,
      const SafetyReportTarget(
        type: SafetyReportTargetType.calendarEvent,
        id: 'partner-event',
      ),
    );
  });

  testWidgets('does not report a current-user-updated calendar event', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      initialDate: DateTime(2026, 5, 5),
      calendarEvents: [
        calendarEvent(
          id: 'my-event',
          title: 'My event',
          date: DateTime(2026, 5, 5),
        ),
      ],
    );

    final myEventMenu = find.byKey(const Key('calendar-event-menu-my-event'));
    await tester.ensureVisible(myEventMenu);
    await tester.pumpAndSettle();
    await tester.tap(myEventMenu);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-event-action-report-my-event')),
      findsNothing,
    );
  });

  testWidgets('keeps styled detail within a narrow enlarged-text viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(
        details: {DateTime(2026, 5, 5): completedDetail},
      ),
      initialDate: DateTime(2026, 5, 5),
      textScaleFactor: 1.3,
    );

    final detailContent = find.byKey(
      const Key('calendar-story-detail-content'),
    );
    final scrollView = find.byKey(const Key('calendar-scroll-view'));
    final storySection = find.byKey(const Key('calendar-story-section'));

    expect(tester.getSize(detailContent).width, 320);
    expect(tester.getSize(storySection).width, 320);
    expect(
      tester.getRect(storySection).right,
      lessThanOrEqualTo(tester.getRect(scrollView).right - 20),
    );
    expect(
      find.byKey(const Key('question-answer-grouped-surface')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
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
    final cardStack = find.byType(CalendarStoryCardStack);
    final card = find.byKey(const ValueKey('calendar-story-card-card-1'));
    final detailContent = find.byKey(
      const Key('calendar-story-detail-content'),
    );
    expect(cardStack, findsOneWidget);
    expect(
      tester.getSize(card).width,
      closeTo((tester.getSize(detailContent).width - 16) / 2, 0.5),
    );
    expect(
      tester.getCenter(card).dx,
      closeTo(tester.getCenter(detailContent).dx, 0.5),
    );
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
