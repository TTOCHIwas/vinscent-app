import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/date/app_date_policy.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/ai/application/ai_question_feedback_provider.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/calendar/presentation/calendar_screen.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_month_story_cell.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_story_card_stack.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_prompt_row.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_sections.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';
import 'package:vinscent/features/story_loops/data/story_loop_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_month_summary_day.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';
import 'package:vinscent/features/story_loops/data/story_loop_status.dart';
import 'package:vinscent/features/story_loops/data/today_story_loop_summary.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_preview_surface.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';
import '../../../support/text_finders.dart';

void main() {
  testWidgets('selects today and loads its detail on entry', (tester) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 10): _todayPendingDetail},
    );
    await _pumpCalendar(tester, repository: repository);

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('날짜를 선택해 주세요'), findsNothing);
    expect(find.text('today history question'), findsOneWidget);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
    expect(
      _circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-10'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );
  });

  testWidgets('swipes one day at a time within the relationship range', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await _pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 9),
    );
    final swipeRegion = find.byKey(const Key('calendar-date-swipe-region'));

    await tester.fling(swipeRegion, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
    ]);
    expect(
      _circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-09'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );

    await tester.fling(swipeRegion, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
    ]);

    await tester.fling(swipeRegion, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(swipeRegion, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
      DateTime(2026, 5, 10),
    ]);
    expect(
      _circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-10'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );
  });

  testWidgets('ignores a short fast date flick', (tester) async {
    final repository = FakeStoryLoopReadRepository();
    await _pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 9),
    );

    await tester.fling(
      find.byKey(const Key('calendar-date-swipe-region')),
      const Offset(64, 0),
      2000,
    );
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets('updates the visible month when a date swipe crosses a month', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await _pumpCalendar(
      tester,
      repository: repository,
      today: DateTime(2026, 6, 1),
    );

    await tester.fling(
      find.byKey(const Key('calendar-date-swipe-region')),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(repository.requestedMonths, [DateTime(2026, 6), DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [
      DateTime(2026, 6, 1),
      DateTime(2026, 5, 31),
    ]);
  });

  testWidgets('does not move before relationship start month', (tester) async {
    final repository = FakeStoryLoopReadRepository();

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 04월'), findsNothing);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
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
    expect(repository.requestedDetailDates, [DateTime(2026, 6, 2)]);
  });

  testWidgets('does not move after today month', (tester) async {
    final repository = FakeStoryLoopReadRepository();

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 06월'), findsNothing);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets(
    'renders month summary cells for empty single and stacked cards',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      final singleCardCell = find.byKey(
        const ValueKey('calendar-month-story-cell-single-2026-05-05'),
      );
      final stackedCardCell = find.byKey(
        const ValueKey('calendar-month-story-cell-stacked-2026-05-06'),
      );
      expect(tester.getSize(singleCardCell).width, greaterThanOrEqualTo(36));
      expect(tester.getSize(singleCardCell).height, greaterThanOrEqualTo(48));

      final singleCard = find.byKey(
        const ValueKey('calendar-month-story-card-month-card-1'),
      );
      final firstStackedCard = find.byKey(
        const ValueKey('calendar-month-story-card-month-card-2'),
      );
      final secondStackedCard = find.byKey(
        const ValueKey('calendar-month-story-card-month-card-3'),
      );
      expect(singleCard, findsOneWidget);
      expect(firstStackedCard, findsOneWidget);
      expect(secondStackedCard, findsOneWidget);
      final cardSize = tester.getSize(singleCard);
      expect(tester.getSize(firstStackedCard), cardSize);
      expect(tester.getSize(secondStackedCard), cardSize);
      expect(
        cardSize.width / cardSize.height,
        closeTo(storyCardCanvasAspectRatio, 0.001),
      );

      final dateInkWell = find.ancestor(
        of: singleCardCell,
        matching: find.byType(InkWell),
      );
      expect(dateInkWell, findsOneWidget);
      expect(
        tester.widget<InkWell>(dateInkWell).child,
        isA<CalendarMonthStoryCell>(),
      );
      final singleCardDecorations = _framedDecorations(tester, singleCardCell);
      final stackedCardDecorations = _framedDecorations(
        tester,
        stackedCardCell,
      );
      expect(singleCardDecorations, hasLength(1));
      expect(stackedCardDecorations, hasLength(2));
      for (final decoration in [
        ...singleCardDecorations,
        ...stackedCardDecorations,
      ]) {
        expect(decoration.border, isNull);
        expect(decoration.boxShadow, hasLength(1));
      }
    },
  );

  testWidgets('fetches selected past date and shows story loop detail', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): _completedDetail},
    );
    await _pumpCalendar(
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
    expect(_framedDecorations(tester, cardStack), hasLength(2));
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
      _circularDecorations(
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
      details: {DateTime(2026, 5, 5): _completedDetail},
    );
    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('calendar-story-card-card-2'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-card-detail-overlay')), findsOneWidget);
    expect(find.byKey(const Key('story-card-detail-card-2')), findsOneWidget);
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
        DateTime(2026, 5, 5): _twoCardDetail(StoryLoopStatus.questionPreparing),
      },
    );

    await _pumpCalendar(tester, repository: repository);
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
        DateTime(2026, 5, 5): _twoCardDetail(StoryLoopStatus.cardOnlyCompleted),
      },
    );

    await _pumpCalendar(tester, repository: repository);
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
    await _pumpCalendar(tester, repository: repository);

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
    final repository = _FlakyStoryLoopReadRepository(entry: _completedDetail);

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 5),
    ]);
    expect(find.text('기록을 불러오지 못했어요'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
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

List<BoxDecoration> _framedDecorations(WidgetTester tester, Finder scope) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(of: scope, matching: find.byType(DecoratedBox)),
      )
      .map((widget) => widget.decoration)
      .whereType<BoxDecoration>()
      .where(
        (decoration) =>
            decoration.border != null ||
            (decoration.boxShadow?.isNotEmpty ?? false),
      )
      .toList(growable: false);
}

List<BoxDecoration> _circularDecorations(WidgetTester tester, Finder scope) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(of: scope, matching: find.byType(DecoratedBox)),
      )
      .map((widget) => widget.decoration)
      .whereType<BoxDecoration>()
      .where((decoration) => decoration.shape == BoxShape.circle)
      .toList(growable: false);
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required StoryLoopReadRepository repository,
  DateTime? today,
  DateTime? relationshipStartDate,
  Map<String, AiQuestionFeedback> aiFeedbacks = const {},
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
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        aiQuestionFeedbackProvider.overrideWith((ref, dailyQuestionId) {
          final feedback = aiFeedbacks[dailyQuestionId];
          return Stream.value(
            feedback == null
                ? const AiQuestionFeedbackDisabled()
                : AiQuestionFeedbackPublished(feedback),
          );
        }),
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

    if (normalizedDate != calendarDateOnly(entry.coupleDate)) {
      return null;
    }

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

final _profile = UserProfile(
  id: 'user-b',
  displayName: 'current user',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
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

StoryLoopDetail _twoCardDetail(StoryLoopStatus status) {
  return StoryLoopDetail(
    coupleId: 'couple-id',
    coupleDate: DateTime(2026, 5, 5),
    accessMode: CoupleAccessMode.active,
    loopId: 'loop-id',
    loopStatus: status,
    storyEditLocked: true,
    canEditStory: false,
    canAnswerQuestion: false,
    cardCount: 2,
    cards: [
      sampleDetailCard(id: 'card-1', submittedAt: DateTime(2026, 5, 5, 9)),
      sampleDetailCard(
        id: 'card-2',
        authorUserId: 'partner-id',
        submittedAt: DateTime(2026, 5, 5, 9, 10),
      ),
    ],
    question: null,
  );
}

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
