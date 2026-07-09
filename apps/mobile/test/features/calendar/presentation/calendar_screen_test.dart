import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/date/app_date_policy.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/calendar/presentation/calendar_screen.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_story_card_stack.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/expressions/data/couple_expression.dart';
import 'package:vinscent/features/expressions/data/couple_expression_repository.dart';
import 'package:vinscent/features/expressions/data/couple_expression_summary.dart';
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
    final expressionRepository = _FakeCoupleExpressionRepository();

    await _pumpCalendar(
      tester,
      repository: repository,
      expressionRepository: expressionRepository,
    );

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('날짜를 선택해 주세요'), findsOneWidget);
    expect(repository.requestedDetailDates, isEmpty);
    expect(expressionRepository.requestedDates, isEmpty);
  });

  testWidgets('does not move before relationship start month', (tester) async {
    final repository = FakeStoryLoopReadRepository();

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 04월'), findsNothing);
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
    expect(repository.requestedDetailDates, isEmpty);
  });

  testWidgets('does not move after today month', (tester) async {
    final repository = FakeStoryLoopReadRepository();

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 06월'), findsNothing);
    expect(repository.requestedDetailDates, isEmpty);
  });

  testWidgets('fetches selected past date and shows story loop detail', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): _completedDetail},
    );
    final expressionRepository = _FakeCoupleExpressionRepository(
      summaries: {
        DateTime(2026, 5, 5): const [
          CoupleExpressionSummary(
            type: CoupleExpressionType.missYou,
            sentCount: 42,
          ),
        ],
      },
    );

    await _pumpCalendar(
      tester,
      repository: repository,
      expressionRepository: expressionRepository,
    );

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
    expect(find.text('그 날의 표현 횟수'), findsOneWidget);
    expect(find.text('보고싶어'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
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
  });

  testWidgets('shows empty state when selected date has no loop', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    final expressionRepository = _FakeCoupleExpressionRepository(
      summaries: {
        DateTime(2026, 5, 5): const [
          CoupleExpressionSummary(
            type: CoupleExpressionType.cheerUp,
            sentCount: 42,
          ),
        ],
      },
    );

    await _pumpCalendar(
      tester,
      repository: repository,
      expressionRepository: expressionRepository,
    );

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 5)]);
    expect(find.text('이 날의 질문 기록이 없어요'), findsOneWidget);
    expect(find.text('그 날의 표현 횟수'), findsOneWidget);
    expect(find.text('힘내'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
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
  CoupleExpressionRepository? expressionRepository,
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
        coupleExpressionRepositoryProvider.overrideWithValue(
          expressionRepository ?? _FakeCoupleExpressionRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();
}

class _FakeCoupleExpressionRepository implements CoupleExpressionRepository {
  _FakeCoupleExpressionRepository({this.summaries = const {}});

  final Map<DateTime, List<CoupleExpressionSummary>> summaries;
  final requestedDates = <DateTime>[];

  @override
  Future<CoupleExpression> send(CoupleExpressionType type) {
    throw UnimplementedError();
  }

  @override
  Future<List<CoupleExpressionSummary>> fetchSummaryByDate(
    DateTime date,
  ) async {
    final normalizedDate = calendarDateOnly(date);
    requestedDates.add(normalizedDate);

    return summaries[normalizedDate] ?? _zeroExpressionSummaries;
  }
}

const _zeroExpressionSummaries = [
  CoupleExpressionSummary(type: CoupleExpressionType.missYou, sentCount: 0),
  CoupleExpressionSummary(type: CoupleExpressionType.thanks, sentCount: 0),
  CoupleExpressionSummary(type: CoupleExpressionType.feelingDown, sentCount: 0),
  CoupleExpressionSummary(type: CoupleExpressionType.cheerUp, sentCount: 0),
];

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
