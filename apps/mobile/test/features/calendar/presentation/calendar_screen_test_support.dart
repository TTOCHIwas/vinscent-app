import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/date/app_date_policy.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/ai/application/ai_question_feedback_provider.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/calendar/application/calendar_cell_preview_mode_controller.dart';
import 'package:vinscent/features/calendar/application/couple_member_birthday_provider.dart';
import 'package:vinscent/features/calendar/data/calendar_cell_preview_mode.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event_repository.dart';
import 'package:vinscent/features/calendar/data/couple_member_birthday.dart';
import 'package:vinscent/features/calendar/presentation/calendar_screen.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/safety/data/safety_report.dart';
import 'package:vinscent/features/safety/data/safety_report_repository.dart';
import 'package:vinscent/features/story_loops/data/story_loop_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_month_summary_day.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';
import 'package:vinscent/features/story_loops/data/story_loop_status.dart';
import 'package:vinscent/features/story_loops/data/today_story_loop_summary.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';

typedef CalendarEventDateRange = ({DateTime startDate, DateTime endDate});

List<BoxDecoration> framedDecorations(WidgetTester tester, Finder scope) {
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

List<BoxDecoration> circularDecorations(WidgetTester tester, Finder scope) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(of: scope, matching: find.byType(DecoratedBox)),
      )
      .map((widget) => widget.decoration)
      .whereType<BoxDecoration>()
      .where((decoration) => decoration.shape == BoxShape.circle)
      .toList(growable: false);
}

Future<GoRouter> pumpCalendar(
  WidgetTester tester, {
  required StoryLoopReadRepository repository,
  DateTime? today,
  DateTime? relationshipStartDate,
  DateTime? initialDate,
  ValueNotifier<DateTime?>? routeDate,
  Map<String, AiQuestionFeedback> aiFeedbacks = const {},
  List<CoupleCalendarEvent> calendarEvents = const [],
  List<CoupleMemberBirthday> memberBirthdays = const [],
  List<CalendarEventDateRange>? calendarEventRequests,
  CalendarCellPreviewMode previewMode = CalendarCellPreviewMode.all,
  Future<CalendarCellPreviewMode>? previewModeResult,
  SafetyReportRepository? safetyReportRepository,
  double textScaleFactor = 1,
}) async {
  final calendarEventRepository = _FakeCalendarEventRepository(
    events: calendarEvents,
    requests: calendarEventRequests,
  );
  final router = GoRouter(
    initialLocation: '/calendar',
    routes: [
      GoRoute(
        path: '/calendar',
        builder: (context, state) {
          final routedDate = parseCalendarDate(
            state.uri.queryParameters['date'],
          );
          return Scaffold(
            body: routeDate == null
                ? CalendarScreen(initialDate: initialDate ?? routedDate)
                : ValueListenableBuilder<DateTime?>(
                    valueListenable: routeDate,
                    builder: (context, value, child) =>
                        CalendarScreen(initialDate: value),
                  ),
          );
        },
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
      GoRoute(
        path: '/calendar/event/new',
        builder: (context, state) => Scaffold(
          body: Text(
            'calendar event date ${state.uri.queryParameters['date']}',
          ),
        ),
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
        calendarCellPreviewModeControllerProvider.overrideWithBuild(
          (ref, notifier) async =>
              await (previewModeResult ?? Future.value(previewMode)),
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
        coupleCalendarEventRepositoryProvider.overrideWithValue(
          calendarEventRepository,
        ),
        coupleMemberBirthdayProvider.overrideWith(
          (ref) async => memberBirthdays,
        ),
        if (safetyReportRepository != null)
          safetyReportRepositoryProvider.overrideWithValue(
            safetyReportRepository,
          ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  return router;
}

Future<void> scrollCalendarUp(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('calendar-scroll-view')),
    const Offset(0, -600),
  );
  await tester.pumpAndSettle();
}

class _FakeCalendarEventRepository implements CoupleCalendarEventRepository {
  _FakeCalendarEventRepository({
    required List<CoupleCalendarEvent> events,
    required this.requests,
  }) : events = List.of(events);

  final List<CoupleCalendarEvent> events;
  final List<CalendarEventDateRange>? requests;

  @override
  Future<void> deleteEvent({
    required String eventId,
    required int expectedRevision,
  }) async {
    events.removeWhere((event) => event.id == eventId);
  }

  @override
  Future<CoupleCalendarEvent?> fetchEvent(String eventId) async {
    return events.where((event) => event.id == eventId).firstOrNull;
  }

  @override
  Future<Uint8List> fetchArtworkDrawingData(String drawingDataPath) async {
    return Uint8List(0);
  }

  @override
  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    requests?.add((startDate: startDate, endDate: endDate));
    return events
        .where(
          (event) =>
              !event.occurrenceDate.isBefore(startDate) &&
              !event.occurrenceDate.isAfter(endDate),
        )
        .toList(growable: false);
  }

  @override
  Future<CoupleCalendarEvent> saveEvent({
    required String coupleId,
    required CoupleCalendarEventSaveRequest request,
    Uint8List? previewBytes,
    Uint8List? drawingDataBytes,
  }) {
    throw UnimplementedError();
  }
}

CoupleCalendarEvent calendarEvent({
  required String id,
  required String title,
  required DateTime date,
  CoupleCalendarEventArtwork? artwork,
}) {
  return CoupleCalendarEvent(
    id: id,
    coupleId: 'couple-id',
    title: title,
    eventDate: date,
    occurrenceDate: date,
    repeatRule: CoupleCalendarEventRepeatRule.none,
    memo: null,
    revision: 1,
    createdByUserId: 'user-id',
    updatedByUserId: 'user-id',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    reminder: const CoupleCalendarEventReminder.disabled(),
    artwork: artwork,
  );
}

class FlakyStoryLoopReadRepository implements StoryLoopReadRepository {
  FlakyStoryLoopReadRepository({required this.entry});

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

final completedDetail = sampleStoryLoopDetail(
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

final aiCompletedDetail = sampleStoryLoopDetail(
  coupleDate: DateTime(2026, 5, 5),
  loopStatus: StoryLoopStatus.completed,
  canEditStory: false,
  canAnswerQuestion: false,
  question: StoryLoopQuestionDetail(
    question: DailyQuestion(
      dailyQuestionId: 'ai-daily-question-id',
      coupleId: 'couple-id',
      questionId: 'ai-question-id',
      questionText: 'AI가 만든 지난 질문',
      questionSource: QuestionSource.ai,
      questionCategory: 'daily',
      questionMood: 'warm',
      assignedDate: DateTime(2026, 5, 5),
      status: DailyQuestionStatus.completed,
    ),
    answerState: const DailyQuestionAnswerState(
      dailyQuestionId: 'ai-daily-question-id',
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

class FakeSafetyReportRepository implements SafetyReportRepository {
  final List<SafetyReportRequest> requests = [];

  @override
  Future<void> submit(SafetyReportRequest request) async {
    requests.add(request);
  }
}

final cardOnlyDetail = StoryLoopDetail(
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

StoryLoopDetail twoCardDetail(StoryLoopStatus status) {
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

final partnerOnlyDetail = sampleStoryLoopDetail(
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

final todayPendingDetail = sampleStoryLoopDetail(
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
