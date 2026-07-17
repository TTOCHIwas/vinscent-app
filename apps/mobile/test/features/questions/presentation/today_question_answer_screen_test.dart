import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_repository.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/questions/presentation/question_route_context.dart';
import 'package:vinscent/features/questions/presentation/today_question_answer_screen.dart';
import 'package:vinscent/features/questions/presentation/widgets/character_speech_prompt.dart';
import 'package:vinscent/features/story_loops/data/story_loop_card_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_month_summary_day.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';
import 'package:vinscent/features/story_loops/data/today_story_loop_summary.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_pair_layout.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_preview_surface.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';

void main() {
  group('TodayQuestionAnswerScreen', () {
    testWidgets('shows readonly empty answer state', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(tester, repository: repository);

      expect(find.text('05월 31일'), findsOneWidget);
      expect(find.text('질문'), findsOneWidget);
      expect(find.text('today question'), findsOneWidget);
      expect(find.text('캐릭터'), findsOneWidget);
      expect(find.text('답변하기'), findsNothing);
      expect(find.text('내 답변'), findsOneWidget);
      expect(find.text('이곳을 눌러서 답변을 입력해주세요'), findsOneWidget);
      expect(find.text('상대방 답변'), findsOneWidget);
      expect(find.text('내 답변을 저장하면 상대방 답변을 확인할 수 있어요'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('저장'), findsNothing);
    });

    testWidgets('shows readonly submitted answer state', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(
        _submittedAnswerState,
      );

      await _pumpRouter(tester, repository: repository);

      expect(find.text('수정'), findsNothing);
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('상대방은 아직 답변하지 않았어요'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('저장'), findsNothing);
    });

    testWidgets('hides partner answer before my answer is saved', (
      tester,
    ) async {
      final repository = _FakeDailyQuestionAnswerRepository(
        _partnerOnlyAnswerState,
      );

      await _pumpRouter(tester, repository: repository);

      expect(find.text('답변하기'), findsNothing);
      expect(find.text('내 답변을 저장하면 상대방 답변을 확인할 수 있어요'), findsOneWidget);
      expect(find.text('partner answer'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows both answers when completed', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(
        _completedAnswerState,
      );

      await _pumpRouter(tester, repository: repository);

      expect(find.text('수정'), findsNothing);
      expect(find.text('내 답변'), findsOneWidget);
      expect(find.text('상대방 답변'), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('partner answer'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('opens edit route from answer action', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(tester, repository: repository);

      await tester.tap(find.text('내 답변'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('저장'), findsOneWidget);
      expect(find.text('상대방 답변'), findsNothing);
    });

    testWidgets('opens edit route from edit action', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(
        _submittedAnswerState,
      );

      await _pumpRouter(tester, repository: repository);

      await tester.tap(find.text('내 답변'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'hello',
      );
      expect(find.text('저장'), findsOneWidget);
      expect(find.text('상대방 답변'), findsNothing);
    });

    testWidgets('retries when question load fails', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);
      final storyLoopRepository = _FailingOnceStoryLoopReadRepository(
        FakeStoryLoopReadRepository(
          details: {
            DateTime(2026, 5, 31): _storyLoopDetailFor(
              date: DateTime(2026, 5, 31),
              question: _dailyQuestion,
              answerState: _emptyAnswerState,
              canAnswerQuestion: true,
            ),
          },
        ),
      );

      await _pumpRouter(
        tester,
        repository: repository,
        storyLoopRepository: storyLoopRepository,
      );

      expect(find.text('질문을 불러오지 못했어요'), findsOneWidget);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('today question'), findsOneWidget);
      expect(find.text('질문을 불러오지 못했어요'), findsNothing);
    });

    testWidgets('shows dated question as readonly history', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(
        tester,
        repository: repository,
        storyLoopDetails: {
          DateTime(2026, 5, 30): _storyLoopDetailFor(
            date: DateTime(2026, 5, 30),
            question: _historyQuestion,
            answerState: _historyAnswerState,
            canAnswerQuestion: false,
          ),
        },
        initialLocation: '/calendar/question?date=2026-05-30',
      );

      expect(find.text('05월 30일'), findsOneWidget);
      expect(find.text('history question'), findsOneWidget);
      expect(find.text('history answer'), findsOneWidget);
      expect(find.text('partner answer'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('내 답변'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows invalid date state for malformed route date', (
      tester,
    ) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(
        tester,
        repository: repository,
        initialLocation: '/calendar/question?date=not-a-date',
      );

      expect(find.text('날짜를 확인할 수 없어요'), findsOneWidget);
      expect(find.text('달력에서 다시 날짜를 선택해주세요.'), findsOneWidget);
    });

    testWidgets('swipes to previous dated question', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(
        tester,
        repository: repository,
        storyLoopDetails: {
          DateTime(2026, 5, 29): _historyDetailFor(
            date: DateTime(2026, 5, 29),
            questionText: 'previous history question',
          ),
          DateTime(2026, 5, 30): _storyLoopDetailFor(
            date: DateTime(2026, 5, 30),
            question: _historyQuestion,
            answerState: _historyAnswerState,
            canAnswerQuestion: false,
          ),
        },
        initialLocation: '/calendar/question?date=2026-05-30',
      );

      await tester.fling(
        find.byType(GestureDetector).first,
        const Offset(400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('05월 29일'), findsOneWidget);
      expect(find.text('previous history question'), findsOneWidget);
    });

    testWidgets('swipes to next date and keeps today editable', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(
        tester,
        repository: repository,
        storyLoopDetails: {
          DateTime(2026, 5, 30): _storyLoopDetailFor(
            date: DateTime(2026, 5, 30),
            question: _historyQuestion,
            answerState: _historyAnswerState,
            canAnswerQuestion: false,
          ),
        },
        initialLocation: '/calendar/question?date=2026-05-30',
      );

      await tester.fling(
        find.byType(GestureDetector).first,
        const Offset(-400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('05월 31일'), findsOneWidget);
      expect(find.text('today question'), findsOneWidget);

      await tester.tap(find.text('내 답변'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('does not swipe before relationship start date', (
      tester,
    ) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(
        tester,
        repository: repository,
        storyLoopDetails: {
          DateTime(2026, 5, 30): _storyLoopDetailFor(
            date: DateTime(2026, 5, 30),
            question: _historyQuestion,
            answerState: _historyAnswerState,
            canAnswerQuestion: false,
          ),
        },
        initialLocation: '/calendar/question?date=2026-05-30',
        relationshipStartDate: DateTime(2026, 5, 30),
      );

      await tester.fling(
        find.byType(GestureDetector).first,
        const Offset(400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('05월 30일'), findsOneWidget);
      expect(find.text('history question'), findsOneWidget);
    });

    testWidgets('does not swipe after today', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(
        tester,
        repository: repository,
        initialLocation: '/home/question?date=2026-05-31',
      );

      await tester.fling(
        find.byType(GestureDetector).first,
        const Offset(-400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('05월 31일'), findsOneWidget);
      expect(find.text('today question'), findsOneWidget);
    });
  });

  group('TodayQuestionAnswerEditScreen', () {
    testWidgets(
      'shows home-sized cards above the horizontal question prompt without page scrolling',
      (tester) async {
        final repository = _FakeDailyQuestionAnswerRepository(
          _emptyAnswerState,
        );
        final targetDate = DateTime(2026, 5, 31);

        await _pumpRouter(
          tester,
          repository: repository,
          initialLocation: '/home/question/edit',
          storyLoopDetails: {
            targetDate: _storyLoopDetailFor(
              date: targetDate,
              question: _dailyQuestion,
              answerState: _emptyAnswerState,
              canAnswerQuestion: true,
              cards: [
                sampleDetailCard(
                  id: 'partner-card',
                  authorUserId: 'partner-id',
                  submittedAt: DateTime.parse('2026-05-31T09:00:00Z'),
                ),
                sampleDetailCard(
                  id: 'my-card',
                  authorUserId: _profile.id,
                  submittedAt: DateTime.parse('2026-05-31T09:10:00Z'),
                ),
              ],
            ),
          },
        );

        final myCard = find.byKey(
          const ValueKey('question-answer-card-my-card'),
        );
        final partnerCard = find.byKey(
          const ValueKey('question-answer-card-partner-card'),
        );
        final character = find.byKey(const Key('question-answer-character'));
        final question = find.byKey(const Key('question-answer-prompt'));

        expect(find.byType(StoryCardPreviewSurface), findsNWidgets(2));
        final speechBubble = tester.widget<CharacterSpeechBubble>(question);
        expect(speechBubble.tailPosition, SpeechBubbleTailPosition.left);
        expect(speechBubble.tailSize, const Size(10, 18));
        expect(
          tester.getSize(myCard).width,
          StoryCardPairLayout.maximumCardWidth,
        );
        expect(
          tester.getSize(myCard).height,
          StoryCardPairLayout.maximumCardHeight,
        );
        expect(
          tester.getCenter(myCard).dx,
          lessThan(tester.getCenter(partnerCard).dx),
        );
        expect(
          tester.getBottomLeft(myCard).dy,
          lessThan(tester.getTopLeft(character).dy),
        );
        expect(
          tester.getCenter(character).dx,
          lessThan(tester.getCenter(question).dx),
        );
        expect(
          find.descendant(
            of: find.byType(TodayQuestionAnswerEditScreen),
            matching: find.byType(SingleChildScrollView),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('collapses cards while the keyboard is visible', (
      tester,
    ) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(
        tester,
        repository: repository,
        initialLocation: '/home/question/edit',
        viewInsetsBottom: 300,
      );

      expect(find.byType(StoryCardPreviewSurface), findsNothing);
      expect(
        find.byKey(const Key('question-answer-character')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('question-answer-prompt')), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('저장'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disables submit for blank answer', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(
        tester,
        repository: repository,
        initialLocation: '/home/question/edit',
      );

      expect(find.text('05월 31일'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('캐릭터'), findsOneWidget);
      expect(find.text('답변 입력'), findsOneWidget);
      expect(find.text('0 / 500'), findsOneWidget);

      await tester.tap(find.text('저장'));
      await tester.pump();

      expect(repository.submitCallCount, 0);
    });

    testWidgets('submits valid answer and returns to readonly screen', (
      tester,
    ) async {
      final repository = _FakeDailyQuestionAnswerRepository(
        _emptyAnswerState,
        submittedState: _submittedAnswerState,
      );

      await _pumpRouter(
        tester,
        repository: repository,
        initialLocation: '/home/question/edit',
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      expect(find.text('5 / 500'), findsOneWidget);

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(repository.submitCallCount, 1);
      expect(repository.submittedAnswers, ['hello']);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('수정'), findsNothing);
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('상대방은 아직 답변하지 않았어요'), findsOneWidget);
    });

    testWidgets('keeps draft and shows inline error when submit fails', (
      tester,
    ) async {
      final repository = _FakeDailyQuestionAnswerRepository(
        _emptyAnswerState,
        submittedState: _submittedAnswerState,
        submitFailuresBeforeSuccess: 1,
      );

      await _pumpRouter(
        tester,
        repository: repository,
        initialLocation: '/home/question/edit',
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(repository.submitCallCount, 1);
      expect(repository.submittedAnswers, ['hello']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'hello',
      );
      expect(find.text('답변을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(repository.submitCallCount, 2);
      expect(repository.submittedAnswers, ['hello', 'hello']);
      expect(find.text('답변을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('disables submit when answer is too long', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(
        tester,
        repository: repository,
        initialLocation: '/home/question/edit',
      );

      await tester.enterText(find.byType(TextField), 'a' * 501);
      await tester.pump();

      expect(find.text('501 / 500'), findsOneWidget);

      await tester.tap(find.text('저장'));
      await tester.pump();

      expect(repository.submitCallCount, 0);
    });

    testWidgets('shows existing answer as editable', (tester) async {
      final repository = _FakeDailyQuestionAnswerRepository(
        _submittedAnswerState,
      );

      await _pumpRouter(
        tester,
        repository: repository,
        initialLocation: '/home/question/edit',
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'hello',
      );
      expect(find.text('저장'), findsOneWidget);
      expect(find.text('상대방 답변'), findsNothing);
    });

    testWidgets('updates answer and returns with partner answer visible', (
      tester,
    ) async {
      final repository = _FakeDailyQuestionAnswerRepository(
        _completedAnswerState,
        submittedState: _editedCompletedAnswerState,
      );

      await _pumpRouter(
        tester,
        repository: repository,
        initialLocation: '/home/question/edit',
      );

      await tester.enterText(find.byType(TextField), 'edited answer');
      await tester.pump();

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(repository.submitCallCount, 1);
      expect(repository.submittedAnswers, ['edited answer']);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('edited answer'), findsOneWidget);
      expect(find.text('partner answer'), findsOneWidget);
    });

    testWidgets('returns to calendar detail when leaving edit with pop stack', (
      tester,
    ) async {
      final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

      await _pumpRouter(
        tester,
        repository: repository,
        initialLocation: '/calendar/question?date=2026-05-31',
      );

      await tester.tap(find.text('내 답변'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('today question'), findsOneWidget);
    });

    testWidgets(
      'submits from calendar source and restores dated detail route',
      (tester) async {
        final repository = _FakeDailyQuestionAnswerRepository(
          _emptyAnswerState,
          submittedState: _submittedAnswerState,
        );

        await _pumpRouter(
          tester,
          repository: repository,
          initialLocation:
              '/home/question/edit?source=calendar&date=2026-05-31',
        );

        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pump();

        await tester.tap(find.text('저장'));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsNothing);
        expect(find.text('hello'), findsOneWidget);
        expect(find.text('today question'), findsOneWidget);
      },
    );
  });
}

Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required _FakeDailyQuestionAnswerRepository repository,
  String initialLocation = '/home/question',
  Map<DateTime, StoryLoopDetail?> storyLoopDetails = const {},
  StoryLoopReadRepository? storyLoopRepository,
  DateTime? relationshipStartDate,
  double viewInsetsBottom = 0,
}) async {
  final today = DateTime(2026, 5, 31);
  final normalizedDetails = <DateTime, StoryLoopDetail?>{
    for (final entry in storyLoopDetails.entries)
      DateTime(entry.key.year, entry.key.month, entry.key.day): entry.value,
  };
  final resolvedStoryLoopRepository =
      storyLoopRepository ??
      _QuestionScreenStoryLoopReadRepository(
        today: today,
        answerRepository: repository,
        details: normalizedDetails,
      );
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home/question',
        builder: (context, state) {
          final dateQuery = state.uri.queryParameters['date'];
          final targetDate = parseQuestionRouteDate(dateQuery);
          return Scaffold(
            body: TodayQuestionAnswerScreen(
              targetDate: targetDate,
              hasInvalidTargetDate: hasInvalidQuestionRouteDate(dateQuery),
            ),
          );
        },
      ),
      GoRoute(
        path: '/home/question/edit',
        builder: (context, state) => Scaffold(
          body: TodayQuestionAnswerEditScreen(
            routeContext: QuestionRouteContext.fromEditUri(state.uri),
          ),
        ),
      ),
      GoRoute(
        path: '/calendar/question',
        builder: (context, state) {
          final dateQuery = state.uri.queryParameters['date'];
          final targetDate = parseQuestionRouteDate(dateQuery);
          return Scaffold(
            body: TodayQuestionAnswerScreen(
              targetDate: targetDate,
              hasInvalidTargetDate: hasInvalidQuestionRouteDate(dateQuery),
              backLocation: '/calendar',
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayControllerProvider.overrideWithBuild(
          (ref, notifier) => DateTime(2026, 5, 31),
        ),
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async =>
              _activeCoupleFor(relationshipStartDate: relationshipStartDate),
        ),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        dailyQuestionAnswerRepositoryProvider.overrideWithValue(repository),
        storyLoopReadRepositoryProvider.overrideWithValue(
          resolvedStoryLoopRepository,
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: EdgeInsets.only(bottom: viewInsetsBottom)),
          child: child!,
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  return router;
}

class _FailingOnceStoryLoopReadRepository implements StoryLoopReadRepository {
  _FailingOnceStoryLoopReadRepository(this.delegate);

  final StoryLoopReadRepository delegate;
  var _hasFailed = false;

  @override
  Future<StoryLoopDetail?> fetchDetail(DateTime date) async {
    if (!_hasFailed) {
      _hasFailed = true;
      throw Exception('detail unavailable');
    }

    return delegate.fetchDetail(date);
  }

  @override
  Future<List<StoryLoopMonthSummaryDay>> fetchMonthSummary(DateTime month) {
    return delegate.fetchMonthSummary(month);
  }

  @override
  Future<TodayStoryLoopSummary?> fetchTodaySummary() {
    return delegate.fetchTodaySummary();
  }
}

class _QuestionScreenStoryLoopReadRepository
    implements StoryLoopReadRepository {
  const _QuestionScreenStoryLoopReadRepository({
    required this.today,
    required this.answerRepository,
    required this.details,
  });

  final DateTime today;
  final _FakeDailyQuestionAnswerRepository answerRepository;
  final Map<DateTime, StoryLoopDetail?> details;

  @override
  Future<StoryLoopDetail?> fetchDetail(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    if (details.containsKey(normalizedDate)) {
      return details[normalizedDate];
    }

    if (normalizedDate == today) {
      return _storyLoopDetailFor(
        date: today,
        question: _dailyQuestion,
        answerState: answerRepository.currentState,
        canAnswerQuestion: true,
      );
    }

    return null;
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

class _FakeDailyQuestionAnswerRepository
    implements DailyQuestionAnswerRepository {
  _FakeDailyQuestionAnswerRepository(
    this.initialState, {
    DailyQuestionAnswerState? submittedState,
    this.submitFailuresBeforeSuccess = 0,
  }) : submittedState = submittedState ?? initialState,
       currentState = initialState;

  final DailyQuestionAnswerState initialState;
  final DailyQuestionAnswerState submittedState;
  int submitFailuresBeforeSuccess;
  DailyQuestionAnswerState currentState;
  final submittedAnswers = <String>[];
  var submitCallCount = 0;

  @override
  Future<DailyQuestionAnswerState> submitStoryLoopAnswer({
    required String dailyQuestionId,
    required String answerText,
  }) async {
    submitCallCount += 1;
    submittedAnswers.add(answerText);
    if (submitFailuresBeforeSuccess > 0) {
      submitFailuresBeforeSuccess -= 1;
      throw Exception('submit failed');
    }

    currentState = submittedState;
    return submittedState;
  }
}

final _dailyQuestion = DailyQuestion(
  dailyQuestionId: 'daily-question-id',
  coupleId: 'couple-id',
  questionId: 'question-id',
  questionText: 'today question',
  questionSource: QuestionSource.curated,
  questionCategory: 'daily',
  questionMood: 'warm',
  assignedDate: DateTime(2026, 5, 31),
  status: DailyQuestionStatus.pending,
);

final _historyQuestion = DailyQuestion(
  dailyQuestionId: 'history-daily-question-id',
  coupleId: 'couple-id',
  questionId: 'history-question-id',
  questionText: 'history question',
  questionSource: QuestionSource.curated,
  questionCategory: 'daily',
  questionMood: 'warm',
  assignedDate: DateTime(2026, 5, 30),
  status: DailyQuestionStatus.completed,
);

final _historyAnswerState = const DailyQuestionAnswerState(
  dailyQuestionId: 'history-daily-question-id',
  status: DailyQuestionStatus.completed,
  myAnswerId: 'history-answer-id',
  myAnswerText: 'history answer',
  partnerAnswerExists: true,
  partnerAnswerId: 'partner-answer-id',
  partnerAnswerText: 'partner answer',
  answerCount: 2,
);

StoryLoopDetail _storyLoopDetailFor({
  required DateTime date,
  required DailyQuestion question,
  required DailyQuestionAnswerState answerState,
  required bool canAnswerQuestion,
  List<StoryLoopCardDetail>? cards,
}) {
  return sampleStoryLoopDetail(
    coupleDate: date,
    canAnswerQuestion: canAnswerQuestion,
    cards: cards,
    question: StoryLoopQuestionDetail(
      question: question,
      answerState: answerState,
    ),
  );
}

final _profile = UserProfile(
  id: 'user-a',
  displayName: '연인',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

StoryLoopDetail _historyDetailFor({
  required DateTime date,
  required String questionText,
}) {
  final question = DailyQuestion(
    dailyQuestionId: 'history-${date.day}-daily-question-id',
    coupleId: 'couple-id',
    questionId: 'history-${date.day}-question-id',
    questionText: questionText,
    questionSource: QuestionSource.curated,
    questionCategory: 'daily',
    questionMood: 'warm',
    assignedDate: date,
    status: DailyQuestionStatus.completed,
  );

  final answerState = DailyQuestionAnswerState(
    dailyQuestionId: 'history-${date.day}-daily-question-id',
    status: DailyQuestionStatus.completed,
    myAnswerId: 'history-${date.day}-answer-id',
    myAnswerText: 'history ${date.day} answer',
    partnerAnswerExists: true,
    partnerAnswerId: 'partner-answer-id',
    partnerAnswerText: 'partner answer',
    answerCount: 2,
  );

  return _storyLoopDetailFor(
    date: date,
    question: question,
    answerState: answerState,
    canAnswerQuestion: false,
  );
}

Couple _activeCoupleFor({DateTime? relationshipStartDate}) {
  return activeCouple(
    inviteCode: 'ABC123',
    userAId: 'user-a-id',
    userBId: 'user-b-id',
    relationshipStartDate: relationshipStartDate ?? DateTime(2026, 5, 1),
    currentDate: DateTime(2026, 5, 31),
    connectedAt: DateTime(2026, 5, 1),
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
  );
}

const _emptyAnswerState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.pending,
  partnerAnswerExists: false,
  answerCount: 0,
);

const _submittedAnswerState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.answeredByOne,
  myAnswerId: 'answer-id',
  myAnswerText: 'hello',
  partnerAnswerExists: false,
  answerCount: 1,
);

const _partnerOnlyAnswerState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.answeredByOne,
  partnerAnswerExists: true,
  partnerAnswerId: 'partner-answer-id',
  partnerAnswerText: 'partner answer',
  answerCount: 1,
);

const _completedAnswerState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.completed,
  myAnswerId: 'answer-id',
  myAnswerText: 'hello',
  partnerAnswerExists: true,
  partnerAnswerId: 'partner-answer-id',
  partnerAnswerText: 'partner answer',
  answerCount: 2,
);

const _editedCompletedAnswerState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.completed,
  myAnswerId: 'answer-id',
  myAnswerText: 'edited answer',
  partnerAnswerExists: true,
  partnerAnswerId: 'partner-answer-id',
  partnerAnswerText: 'partner answer',
  answerCount: 2,
);
