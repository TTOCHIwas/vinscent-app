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
import 'package:vinscent/features/questions/application/today_question_controller.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_repository.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/questions/data/daily_question_history_entry.dart';
import 'package:vinscent/features/questions/data/daily_question_history_repository.dart';
import 'package:vinscent/features/shell/presentation/widgets/app_bottom_bar.dart';
import 'package:vinscent/features/shell/presentation/widgets/app_header.dart';
import 'package:vinscent/features/shell/presentation/widgets/shell_tab.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';

import '../../support/couple_fixtures.dart';
import '../../support/question_answer_fixtures.dart';
import '../../support/story_loop_fixtures.dart';

void main() {
  testWidgets('shows shell around authenticated home route', (tester) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      answerRepository: FakeDailyQuestionAnswerRepository(pendingAnswerState),
    );

    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('달력'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('오늘의 질문'), findsOneWidget);
  });

  testWidgets('moves between shell routes through bottom bar and header', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      answerRepository: FakeDailyQuestionAnswerRepository(pendingAnswerState),
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

  testWidgets('opens question edit route when my answer is missing', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      answerRepository: FakeDailyQuestionAnswerRepository(pendingAnswerState),
    );

    await tester.tap(find.text(_dailyQuestion.questionText));
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsNothing);
    expect(find.byType(AppBottomBar), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('내 답변'), findsNothing);
  });

  testWidgets('opens readonly question route after my answer is written', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      answerRepository: FakeDailyQuestionAnswerRepository(myAnswerOnlyState()),
    );

    await tester.tap(find.text('상대방의 답변을 기다리고 있어요.'));
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsNothing);
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('내 답변'), findsOneWidget);
    expect(_tabs(tester).first.isSelected, isTrue);
  });

  testWidgets('opens readonly question route from ai placeholder state', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      answerRepository: FakeDailyQuestionAnswerRepository(completedAnswerState),
    );

    await tester.tap(find.text('AI 한 줄 평이 여기에 표시될 예정이에요.'));
    await tester.pumpAndSettle();

    expect(find.byType(AppHeader), findsNothing);
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('상대방 답변'), findsOneWidget);
    expect(_tabs(tester).first.isSelected, isTrue);
  });

  testWidgets('opens dated question answer route under calendar tab', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      question: _dailyQuestion,
      answerRepository: FakeDailyQuestionAnswerRepository(pendingAnswerState),
      historyRepository: const _FakeDailyQuestionHistoryRepository(),
    );

    GoRouter.of(
      tester.element(find.text('오늘의 질문')),
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
  required FakeDailyQuestionAnswerRepository answerRepository,
  DailyQuestionHistoryRepository? historyRepository,
}) async {
  final storyLoopRepository = FakeStoryLoopReadRepository(
    details: {
      _today: sampleStoryLoopDetail(
        coupleDate: _today,
        canAnswerQuestion: true,
        question: StoryLoopQuestionDetail(
          question: question,
          answerState: answerRepository.currentState,
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
        todayQuestionControllerProvider.overrideWithBuild(
          (ref, notifier) async => question,
        ),
        dailyQuestionAnswerRepositoryProvider.overrideWithValue(
          answerRepository,
        ),
        dailyQuestionHistoryRepositoryProvider.overrideWithValue(
          historyRepository ?? const _FakeDailyQuestionHistoryRepository(),
        ),
        storyLoopReadRepositoryProvider.overrideWithValue(storyLoopRepository),
      ],
      child: const VinscentApp(),
    ),
  );

  await tester.pumpAndSettle();
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

class _FakeDailyQuestionHistoryRepository
    implements DailyQuestionHistoryRepository {
  const _FakeDailyQuestionHistoryRepository();

  @override
  Future<DailyQuestionHistoryEntry?> fetchByDate(DateTime date) async {
    return DailyQuestionHistoryEntry(
      question: _historyQuestion,
      answerState: _historyAnswerState,
    );
  }
}

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
