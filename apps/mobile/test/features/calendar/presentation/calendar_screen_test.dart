import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/date/app_date_policy.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/calendar/presentation/calendar_screen.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_month_story_cell.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_story_card_stack.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/story_loops/data/story_loop_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_month_summary_day.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';
import 'package:vinscent/features/story_loops/data/story_loop_status.dart';
import 'package:vinscent/features/story_loops/data/today_story_loop_summary.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';

void main() {
  testWidgets('shows current month without fetching detail before selection', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await _pumpCalendar(tester, repository: repository);

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('날짜를 선택해 주세요'), findsOneWidget);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, isEmpty);
  });

  testWidgets('does not move before relationship start month', (tester) async {
    final repository = FakeStoryLoopReadRepository();

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 04월'), findsNothing);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, isEmpty);
  });

  testWidgets('moves to previous month after relationship start month', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();

    await _pumpCalendar(
      tester,
      repository: repository,
      today: DateTime(2026, 6, 2),
    );

    expect(find.text('2026년 06월'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(repository.requestedMonths, [DateTime(2026, 6), DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, isEmpty);
  });

  testWidgets('does not move after today month', (tester) async {
    final repository = FakeStoryLoopReadRepository();

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 06월'), findsNothing);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, isEmpty);
  });

  testWidgets(
    'renders month summary cells for empty single and stacked cards',
    (tester) async {
      final repository = FakeStoryLoopReadRepository(
        monthSummaries: {
          DateTime(2026, 5): [
            sampleMonthSummaryDay(
              coupleDate: DateTime(2026, 5, 5),
              cardCount: 1,
              cards: [
                samplePreviewCard(
                  id: 'month-card-1',
                  submittedAt: DateTime(2026, 5, 5, 9, 0),
                ),
              ],
            ),
            sampleMonthSummaryDay(
              coupleDate: DateTime(2026, 5, 6),
              cardCount: 2,
              cards: [
                samplePreviewCard(
                  id: 'month-card-2',
                  submittedAt: DateTime(2026, 5, 6, 9, 20),
                ),
                samplePreviewCard(
                  id: 'month-card-3',
                  authorUserId: 'user-b',
                  previewPath: 'previews/card-3.png',
                  submittedAt: DateTime(2026, 5, 6, 9, 0),
                ),
              ],
            ),
          ],
        },
      );

      await _pumpCalendar(tester, repository: repository);

      expect(
        find.byKey(
          const ValueKey('calendar-month-story-cell-single-2026-05-05'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('calendar-month-story-cell-stacked-2026-05-06'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-07'),
        ),
        findsOneWidget,
      );
      expect(find.byType(CalendarMonthStoryCell), findsWidgets);
    },
  );

  testWidgets('fetches selected past date and shows story loop detail', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): _completedDetail},
    );
    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 5)]);
    expect(find.text('2026년 05월 05일'), findsOneWidget);
    expect(find.byType(CalendarStoryCardStack), findsOneWidget);
    expect(find.text('history question'), findsOneWidget);
    expect(find.text('my answer'), findsOneWidget);
    expect(find.text('partner answer'), findsOneWidget);
    expect(find.text('종합'), findsOneWidget);
    expect(find.text('AI 한 줄 평'), findsOneWidget);
    expect(find.text('아직 AI 한 줄 평이 없어요'), findsOneWidget);
    expect(find.text('그 날의 표현 횟수'), findsNothing);
  });

  testWidgets('shows card only detail when question has not been generated', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): _cardOnlyDetail},
    );

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 5)]);
    expect(find.byType(CalendarStoryCardStack), findsOneWidget);
    expect(find.text('스토리 카드가 먼저 도착했어요'), findsOneWidget);
    expect(find.text('두 사람의 카드가 모두 올라오면 질문이 생성돼요'), findsOneWidget);
    expect(find.text('history question'), findsNothing);
    expect(find.text('09:00'), findsNothing);
  });

  testWidgets('shows empty state when selected date has no loop', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 5)]);
    expect(find.text('이 날의 질문 기록이 없어요'), findsOneWidget);
    expect(find.text('그 날의 표현 횟수'), findsNothing);
  });

  testWidgets('retries selected past date after detail load failure', (
    tester,
  ) async {
    final repository = _FlakyStoryLoopReadRepository(entry: _completedDetail);

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 5)]);
    expect(find.text('기록을 불러오지 못했어요'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 5),
      DateTime(2026, 5, 5),
    ]);
    expect(find.text('history question'), findsOneWidget);
  });

  testWidgets('uses history hidden copy when my answer is missing', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): _partnerOnlyDetail},
    );

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('내 답변이 없어 상대방 답변을 확인할 수 없어요'), findsOneWidget);
    expect(find.text('partner answer'), findsNothing);
    expect(find.text('AI 한 줄 평'), findsNothing);
    expect(find.text('아직 AI 한 줄 평이 없어요'), findsNothing);
  });

  testWidgets('selects today without leaving calendar', (tester) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 10): _todayPendingDetail},
    );

    await _pumpCalendar(tester, repository: repository);

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
      details: {DateTime(2026, 5, 10): _todayPendingDetail},
    );

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('내 답변'));
    await tester.tap(find.text('내 답변'));
    await tester.pumpAndSettle();

    expect(find.text('calendar question edit route'), findsOneWidget);
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required StoryLoopReadRepository repository,
  DateTime? today,
  DateTime? relationshipStartDate,
}) async {
  final router = GoRouter(
    initialLocation: '/calendar',
    routes: [
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const Scaffold(body: CalendarScreen()),
      ),
      GoRoute(
        path: '/calendar/question',
        builder: (context, state) =>
            const Scaffold(body: Text('calendar question route')),
      ),
      GoRoute(
        path: '/home/question/edit',
        builder: (context, state) =>
            const Scaffold(body: Text('calendar question edit route')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayControllerProvider.overrideWithBuild(
          (ref, notifier) => today ?? DateTime(2026, 5, 10),
        ),
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => _activeCouple(
            relationshipStartDate: relationshipStartDate,
            currentDate: today ?? DateTime(2026, 5, 10),
          ),
        ),
        storyLoopReadRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();
}

class _FlakyStoryLoopReadRepository implements StoryLoopReadRepository {
  _FlakyStoryLoopReadRepository({required this.entry});

  final StoryLoopDetail entry;
  final requestedDetailDates = <DateTime>[];
  var _shouldFail = true;

  @override
  Future<StoryLoopDetail?> fetchDetail(DateTime date) async {
    final normalizedDate = calendarDateOnly(date);
    requestedDetailDates.add(normalizedDate);

    if (_shouldFail) {
      _shouldFail = false;
      throw Exception('detail unavailable');
    }

    return entry;
  }

  @override
  Future<List<StoryLoopMonthSummaryDay>> fetchMonthSummary(
    DateTime month,
  ) async {
    return const [];
  }

  @override
  Future<TodayStoryLoopSummary?> fetchTodaySummary() async {
    return null;
  }
}

Couple _activeCouple({DateTime? relationshipStartDate, DateTime? currentDate}) {
  return activeCouple(
    relationshipStartDate: relationshipStartDate ?? DateTime(2026, 5, 1),
    currentDate: currentDate ?? DateTime(2026, 5, 10),
  );
}

final _historyQuestion = DailyQuestion(
  dailyQuestionId: 'daily-question-id',
  coupleId: 'couple-id',
  questionId: 'question-id',
  questionText: 'history question',
  questionSource: QuestionSource.curated,
  questionCategory: 'daily',
  questionMood: 'warm',
  assignedDate: DateTime(2026, 5, 5),
  status: DailyQuestionStatus.completed,
);

final _completedDetail = sampleStoryLoopDetail(
  coupleDate: DateTime(2026, 5, 5),
  loopStatus: StoryLoopStatus.completed,
  canEditStory: false,
  canAnswerQuestion: false,
  cards: [
    sampleDetailCard(id: 'card-1', submittedAt: DateTime(2026, 5, 5, 9, 0)),
    sampleDetailCard(
      id: 'card-2',
      authorUserId: 'user-b',
      previewPath: 'previews/card-2.png',
      sceneDataPath: 'scenes/card-2.json',
      submittedAt: DateTime(2026, 5, 5, 9, 10),
    ),
  ],
  question: StoryLoopQuestionDetail(
    question: _historyQuestion,
    answerState: const DailyQuestionAnswerState(
      dailyQuestionId: 'daily-question-id',
      status: DailyQuestionStatus.completed,
      myAnswerId: 'my-answer-id',
      myAnswerText: 'my answer',
      partnerAnswerExists: true,
      partnerAnswerId: 'partner-answer-id',
      partnerAnswerText: 'partner answer',
      answerCount: 2,
    ),
  ),
);

final _cardOnlyDetail = StoryLoopDetail(
  coupleId: 'couple-id',
  coupleDate: DateTime(2026, 5, 5),
  accessMode: CoupleAccessMode.active,
  loopId: 'loop-id',
  loopStatus: StoryLoopStatus.waitingPartnerCard,
  storyEditLocked: false,
  canEditStory: false,
  canAnswerQuestion: false,
  cardCount: 1,
  cards: [
    sampleDetailCard(id: 'card-1', submittedAt: DateTime(2026, 5, 5, 9, 0)),
  ],
  question: null,
);

final _partnerOnlyDetail = sampleStoryLoopDetail(
  coupleDate: DateTime(2026, 5, 5),
  loopStatus: StoryLoopStatus.answeredByOne,
  canEditStory: false,
  canAnswerQuestion: false,
  question: StoryLoopQuestionDetail(
    question: _historyQuestion,
    answerState: const DailyQuestionAnswerState(
      dailyQuestionId: 'daily-question-id',
      status: DailyQuestionStatus.answeredByOne,
      partnerAnswerExists: true,
      answerCount: 1,
    ),
  ),
);

final _todayPendingDetail = sampleStoryLoopDetail(
  coupleDate: DateTime(2026, 5, 10),
  loopStatus: StoryLoopStatus.questionGenerated,
  canEditStory: false,
  canAnswerQuestion: true,
  question: StoryLoopQuestionDetail(
    question: DailyQuestion(
      dailyQuestionId: 'today-daily-question-id',
      coupleId: 'couple-id',
      questionId: 'today-question-id',
      questionText: 'today history question',
      questionSource: QuestionSource.curated,
      questionCategory: 'daily',
      questionMood: 'warm',
      assignedDate: DateTime(2026, 5, 10),
      status: DailyQuestionStatus.pending,
    ),
    answerState: const DailyQuestionAnswerState(
      dailyQuestionId: 'today-daily-question-id',
      status: DailyQuestionStatus.pending,
      partnerAnswerExists: false,
      answerCount: 0,
    ),
  ),
);
