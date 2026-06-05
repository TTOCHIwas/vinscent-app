import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/date/app_date_policy.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/calendar/presentation/calendar_screen.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/questions/data/daily_question_history_entry.dart';
import 'package:vinscent/features/questions/data/daily_question_history_repository.dart';

void main() {
  testWidgets('shows current month without fetching history before selection', (
    tester,
  ) async {
    final repository = _FakeDailyQuestionHistoryRepository();

    await _pumpCalendar(tester, repository: repository);

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('날짜를 선택해 주세요'), findsOneWidget);
    expect(repository.requestedDates, isEmpty);
  });

  testWidgets('does not move before relationship start month', (tester) async {
    final repository = _FakeDailyQuestionHistoryRepository();

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 04월'), findsNothing);
    expect(repository.requestedDates, isEmpty);
  });

  testWidgets('moves to previous month after relationship start month', (
    tester,
  ) async {
    final repository = _FakeDailyQuestionHistoryRepository();

    await _pumpCalendar(
      tester,
      repository: repository,
      today: DateTime(2026, 6, 2),
    );

    expect(find.text('2026년 06월'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(repository.requestedDates, isEmpty);
  });

  testWidgets('does not move after today month', (tester) async {
    final repository = _FakeDailyQuestionHistoryRepository();

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 06월'), findsNothing);
    expect(repository.requestedDates, isEmpty);
  });

  testWidgets('fetches selected past date and shows history detail', (
    tester,
  ) async {
    final repository = _FakeDailyQuestionHistoryRepository(
      entries: {DateTime(2026, 5, 5): _completedEntry},
    );

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDates, [DateTime(2026, 5, 5)]);
    expect(find.text('2026년 05월 05일'), findsOneWidget);
    expect(find.text('history question'), findsOneWidget);
    expect(find.text('my answer'), findsOneWidget);
    expect(find.text('partner answer'), findsOneWidget);
    expect(find.text('종합'), findsOneWidget);
    expect(find.text('AI 한 줄 평'), findsOneWidget);
    expect(find.text('이 날의 표현 횟수'), findsOneWidget);
  });

  testWidgets(
    'shows empty state when selected date has no generated question',
    (tester) async {
      final repository = _FakeDailyQuestionHistoryRepository();

      await _pumpCalendar(tester, repository: repository);

      await tester.tap(find.text('5').first);
      await tester.pumpAndSettle();

      expect(repository.requestedDates, [DateTime(2026, 5, 5)]);
      expect(find.text('이 날의 질문 기록이 없어요'), findsOneWidget);
    },
  );

  testWidgets('retries selected past date after history load failure', (
    tester,
  ) async {
    final repository = _FlakyDailyQuestionHistoryRepository(
      entry: _completedEntry,
    );

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDates, [DateTime(2026, 5, 5)]);
    expect(find.text('기록을 불러오지 못했어요'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(repository.requestedDates, [
      DateTime(2026, 5, 5),
      DateTime(2026, 5, 5),
    ]);
    expect(find.text('history question'), findsOneWidget);
  });

  testWidgets('uses history hidden copy when my answer is missing', (
    tester,
  ) async {
    final repository = _FakeDailyQuestionHistoryRepository(
      entries: {DateTime(2026, 5, 5): _partnerOnlyEntry},
    );

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('내 답변이 없어 상대방 답변을 확인할 수 없어요'), findsOneWidget);
    expect(find.text('partner answer'), findsNothing);
  });

  testWidgets('selects today without leaving calendar', (
    tester,
  ) async {
    final repository = _FakeDailyQuestionHistoryRepository(
      entries: {DateTime(2026, 5, 10): _todayEntry},
    );

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    expect(repository.requestedDates, [DateTime(2026, 5, 10)]);
    expect(find.text('today question route'), findsNothing);
    expect(find.text('today history question'), findsOneWidget);
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required DailyQuestionHistoryRepository repository,
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
        path: '/home/question',
        builder: (context, state) =>
            const Scaffold(body: Text('today question route')),
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
          (ref, notifier) async =>
              _activeCouple(relationshipStartDate: relationshipStartDate),
        ),
        dailyQuestionHistoryRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();
}

class _FakeDailyQuestionHistoryRepository
    implements DailyQuestionHistoryRepository {
  _FakeDailyQuestionHistoryRepository({this.entries = const {}});

  final Map<DateTime, DailyQuestionHistoryEntry> entries;
  final requestedDates = <DateTime>[];

  @override
  Future<DailyQuestionHistoryEntry?> fetchByDate(DateTime date) async {
    final normalizedDate = calendarDateOnly(date);
    requestedDates.add(normalizedDate);
    return entries[normalizedDate];
  }
}

class _FlakyDailyQuestionHistoryRepository
    implements DailyQuestionHistoryRepository {
  _FlakyDailyQuestionHistoryRepository({required this.entry});

  final DailyQuestionHistoryEntry entry;
  final requestedDates = <DateTime>[];
  var _shouldFail = true;

  @override
  Future<DailyQuestionHistoryEntry?> fetchByDate(DateTime date) async {
    final normalizedDate = calendarDateOnly(date);
    requestedDates.add(normalizedDate);

    if (_shouldFail) {
      _shouldFail = false;
      throw Exception('history unavailable');
    }

    return entry;
  }
}

Couple _activeCouple({DateTime? relationshipStartDate}) {
  return Couple(
    id: 'couple-id',
    inviteCode: 'ABC234',
    userAId: 'user-id',
    userBId: 'partner-id',
    relationshipStartDate: relationshipStartDate ?? DateTime(2026, 5, 1),
    timezone: 'Asia/Seoul',
    status: CoupleStatus.active,
    connectedAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
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

final _completedEntry = DailyQuestionHistoryEntry(
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
);

final _partnerOnlyEntry = DailyQuestionHistoryEntry(
  question: _historyQuestion,
  answerState: const DailyQuestionAnswerState(
    dailyQuestionId: 'daily-question-id',
    status: DailyQuestionStatus.answeredByOne,
    partnerAnswerExists: true,
    answerCount: 1,
  ),
);

final _todayEntry = DailyQuestionHistoryEntry(
  question: DailyQuestion(
    dailyQuestionId: 'today-daily-question-id',
    coupleId: 'couple-id',
    questionId: 'today-question-id',
    questionText: 'today history question',
    questionSource: QuestionSource.curated,
    questionCategory: 'daily',
    questionMood: 'warm',
    assignedDate: DateTime(2026, 5, 10),
    status: DailyQuestionStatus.completed,
  ),
  answerState: const DailyQuestionAnswerState(
    dailyQuestionId: 'today-daily-question-id',
    status: DailyQuestionStatus.completed,
    myAnswerId: 'my-answer-id',
    myAnswerText: 'today answer',
    partnerAnswerExists: true,
    partnerAnswerId: 'partner-answer-id',
    partnerAnswerText: 'partner answer',
    answerCount: 2,
  ),
);
