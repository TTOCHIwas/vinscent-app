import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/app/app.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/shell/presentation/widgets/app_bottom_bar.dart';
import 'package:vinscent/features/shell/presentation/widgets/app_header.dart';
import 'package:vinscent/features/shell/presentation/widgets/shell_tab.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_summary.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';
import 'package:vinscent/features/story_loops/data/story_loop_status.dart';

import '../../support/couple_fixtures.dart';
import '../../support/question_answer_fixtures.dart';
import '../../support/story_loop_fixtures.dart';

void main() {
  testWidgets('인증된 홈 경로에 shell을 보여준다', (tester) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      todayAnswerState: pendingAnswerState,
    );

    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.text('D+2'), findsOneWidget);
    expect(tester.widget<Text>(find.text('D+2')).style?.fontSize, 24);
    expect(find.text('앱 이름'), findsNothing);
    final headerRow = tester.widget<Row>(
      find.descendant(of: find.byType(AppHeader), matching: find.byType(Row)),
    );
    expect(headerRow.mainAxisAlignment, MainAxisAlignment.spaceBetween);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('달력'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('오늘의 스토리'), findsOneWidget);
  });

  testWidgets('bottom bar와 header로 shell route를 이동한다', (tester) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      todayAnswerState: pendingAnswerState,
    );

    await tester.tap(find.text('달력'));
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsNothing);
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.text('2026년 05월'), findsOneWidget);
    expect(_tabs(tester)[1].isSelected, isTrue);

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(_tabs(tester)[2].isSelected, isTrue);

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsNothing);
    expect(find.byType(AppBottomBar), findsNothing);
    expect(find.text('설정'), findsOneWidget);
  });

  testWidgets('내 답변이 없으면 답변 작성 route로 이동한다', (tester) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      todayAnswerState: pendingAnswerState,
    );

    await tester.ensureVisible(find.text('답변 남기기'));
    await tester.tap(find.text('답변 남기기'));
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsNothing);
    expect(find.byType(AppBottomBar), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('내 답변'), findsNothing);
  });

  testWidgets('내 답변이 있으면 읽기 전용 질문 route로 이동한다', (tester) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      todayAnswerState: myAnswerOnlyState(),
    );

    await tester.ensureVisible(find.text('오늘 질문 보기'));
    await tester.tap(find.text('오늘 질문 보기'));
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsNothing);
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('내 답변'), findsOneWidget);
    expect(_tabs(tester).first.isSelected, isTrue);
  });

  testWidgets('AI placeholder 상태에서도 읽기 전용 질문 route로 이동한다', (tester) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      todayAnswerState: completedAnswerState,
    );

    expect(find.text('AI 한 줄 평이 여기에 표시될 예정이에요.'), findsOneWidget);

    await tester.ensureVisible(find.text('오늘 질문 보기'));
    await tester.tap(find.text('오늘 질문 보기'));
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsNothing);
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('상대방 답변'), findsOneWidget);
    expect(_tabs(tester).first.isSelected, isTrue);
  });

  testWidgets('달력 탭의 날짜 질문 route를 연다', (tester) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      todayAnswerState: pendingAnswerState,
    );

    GoRouter.of(
      tester.element(find.text('오늘의 스토리')),
    ).go('/calendar/question?date=2026-05-30');
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsNothing);
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.text('05월 30일'), findsOneWidget);
    expect(find.text('history question'), findsOneWidget);
    expect(_tabs(tester)[1].isSelected, isTrue);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required DailyQuestion question,
  required DailyQuestionAnswerState todayAnswerState,
}) async {
  final storyLoopRepository = FakeStoryLoopReadRepository(
    todaySummary: sampleTodaySummary(
      coupleDate: _today,
      loopStatus: _summaryStatusFor(todayAnswerState),
      question: StoryLoopQuestionSummary(
        question: question,
        myAnswerExists: todayAnswerState.hasMyAnswer,
        partnerAnswerExists: todayAnswerState.partnerAnswerExists,
        answerCount: todayAnswerState.answerCount,
      ),
    ),
    details: {
      _today: sampleStoryLoopDetail(
        coupleDate: _today,
        canAnswerQuestion: true,
        loopStatus: _summaryStatusFor(todayAnswerState),
        question: StoryLoopQuestionDetail(
          question: question,
          answerState: todayAnswerState,
        ),
      ),
      DateTime(2026, 5, 30): sampleStoryLoopDetail(
        coupleDate: DateTime(2026, 5, 30),
        canAnswerQuestion: false,
        question: StoryLoopQuestionDetail(
          question: _historyQuestion,
          answerState: _historyAnswerState,
        ),
      ),
    },
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (ref, notifier) => AuthStatus.authenticated,
        ),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => _activeCouple,
        ),
        todayControllerProvider.overrideWithBuild((ref, notifier) => _today),
        storyLoopReadRepositoryProvider.overrideWithValue(storyLoopRepository),
      ],
      child: const VinscentApp(),
    ),
  );

  await tester.pumpAndSettle();
}

StoryLoopStatus _summaryStatusFor(DailyQuestionAnswerState state) {
  if (state.hasMyAnswer && state.partnerAnswerExists) {
    return StoryLoopStatus.completed;
  }

  if (state.hasMyAnswer || state.partnerAnswerExists) {
    return StoryLoopStatus.answeredByOne;
  }

  return StoryLoopStatus.questionGenerated;
}

List<ShellTab> _tabs(WidgetTester tester) {
  return tester.widgetList<ShellTab>(find.byType(ShellTab)).toList();
}

final _today = DateTime(2026, 5, 31);

final _profile = UserProfile(
  id: 'user-id',
  displayName: '연인',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _activeCouple = activeCouple(
  relationshipStartDate: DateTime(2026, 5, 30),
  currentDate: _today,
);

final _dailyQuestion = DailyQuestion(
  dailyQuestionId: 'daily-question-id',
  coupleId: 'couple-id',
  questionId: 'question-id',
  questionText: 'today question',
  questionSource: QuestionSource.curated,
  questionCategory: 'daily',
  questionMood: 'warm',
  assignedDate: _today,
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

const _historyAnswerState = DailyQuestionAnswerState(
  dailyQuestionId: 'history-daily-question-id',
  status: DailyQuestionStatus.completed,
  myAnswerId: 'answer-id',
  myAnswerText: 'history answer',
  partnerAnswerExists: true,
  partnerAnswerId: 'partner-answer-id',
  partnerAnswerText: 'partner answer',
  answerCount: 2,
);
