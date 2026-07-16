import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/app/app.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/calendar/presentation/calendar_screen.dart';
import 'package:vinscent/features/characters/presentation/character_editor_screen.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/questions/presentation/today_question_answer_screen.dart';
import 'package:vinscent/features/settings/presentation/settings_screen.dart';
import 'package:vinscent/features/shell/presentation/app_shell.dart';
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
  testWidgets(
    '\uc778\uc99d\ub41c \ud648 \uacbd\ub85c\uc5d0 shell\uacfc \uc9c8\ubb38\uc744 \ubcf4\uc5ec\uc900\ub2e4',
    (tester) async {
      await _pumpApp(
        tester,
        question: _dailyQuestion,
        todayAnswerState: pendingAnswerState,
      );

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.byType(AppBottomBar), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppBottomBar)).height,
        AppShell.bottomBarHeight,
      );
      expect(AppShell.bottomBarHeight, 88);
      expect(
        find.descendant(
          of: find.byType(AppBottomBar),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byTooltip('\ud648'), findsOneWidget);
      expect(find.byTooltip('\ub2ec\ub825'), findsOneWidget);
      expect(find.byTooltip('AI'), findsOneWidget);
      expect(find.text('AI'), findsNothing);
      expect(find.text('D+2'), findsOneWidget);
      expect(tester.widget<Text>(find.text('D+2')).style?.fontSize, 24);
      final headerRow = tester.widget<Row>(
        find.descendant(of: find.byType(AppHeader), matching: find.byType(Row)),
      );
      expect(headerRow.mainAxisAlignment, MainAxisAlignment.spaceBetween);
      expect(find.byType(ShellTab), findsNWidgets(3));
      expect(find.text(_dailyQuestion.questionText), findsOneWidget);
      expect(find.text('\uc624\ub298\uc758 \uc2a4\ud1a0\ub9ac'), findsNothing);
    },
  );

  testWidgets(
    'bottom bar\uc640 header\ub85c shell route\ub97c \uc774\ub3d9\ud55c\ub2e4',
    (tester) async {
      await _pumpApp(
        tester,
        question: _dailyQuestion,
        todayAnswerState: pendingAnswerState,
      );

      await tester.tap(find.byType(ShellTab).at(1));
      await tester.pumpAndSettle();

      expect(find.byType(AppHeader), findsNothing);
      expect(find.byType(AppBottomBar), findsOneWidget);
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(_tabs(tester)[1].isSelected, isTrue);

      await tester.tap(find.byType(ShellTab).at(2));
      await tester.pumpAndSettle();

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.byType(AppBottomBar), findsOneWidget);
      expect(_tabs(tester)[2].isSelected, isTrue);

      final settingsControl = find.descendant(
        of: find.byType(AppHeader),
        matching: find.byType(InkWell),
      );
      await tester.tap(settingsControl);
      await tester.pumpAndSettle();

      expect(find.byType(AppHeader), findsNothing);
      expect(find.byType(AppBottomBar), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    },
  );

  testWidgets(
    '\ub0b4 \ub2f5\ubcc0\uc774 \uc5c6\uc73c\uba74 \uc9c8\ubb38 \ud0ed\uc73c\ub85c \ub2f5\ubcc0 \uc791\uc131 route\ub97c \uc5f0\ub2e4',
    (tester) async {
      await _pumpApp(
        tester,
        question: _dailyQuestion,
        todayAnswerState: pendingAnswerState,
      );

      final question = find.text(_dailyQuestion.questionText);
      expect(question.hitTestable(), findsOneWidget);

      await tester.tap(question);
      await tester.pumpAndSettle();

      expect(find.byType(AppHeader), findsNothing);
      expect(find.byType(AppBottomBar), findsNothing);
      expect(find.byType(TodayQuestionAnswerEditScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    },
  );

  testWidgets(
    '\ub0b4 \ub2f5\ubcc0\uc774 \uc788\uc73c\uba74 \uc9c8\ubb38 \ud0ed\uc73c\ub85c \uc77d\uae30 \uc804\uc6a9 route\ub97c \uc5f0\ub2e4',
    (tester) async {
      await _pumpApp(
        tester,
        question: _dailyQuestion,
        todayAnswerState: myAnswerOnlyState(),
      );

      await tester.tap(find.text(_dailyQuestion.questionText));
      await tester.pumpAndSettle();

      expect(find.byType(AppHeader), findsNothing);
      expect(find.byType(AppBottomBar), findsOneWidget);
      expect(find.byType(TodayQuestionAnswerScreen), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(_tabs(tester).first.isSelected, isTrue);
    },
  );

  testWidgets(
    '\uc591\ucabd \ub2f5\ubcc0 \uc644\ub8cc \uc0c1\ud0dc\uc5d0\uc11c\ub3c4 \uc9c8\ubb38 \ud0ed\uc73c\ub85c \uc77d\uae30 route\ub97c \uc5f0\ub2e4',
    (tester) async {
      await _pumpApp(
        tester,
        question: _dailyQuestion,
        todayAnswerState: completedAnswerState,
      );

      expect(find.text(_dailyQuestion.questionText), findsOneWidget);
      expect(
        find.text(
          'AI \ud55c \uc904 \ud3c9\uc774 \uc5ec\uae30\uc5d0 \ud45c\uc2dc\ub420 \uc608\uc815\uc774\uc5d0\uc694.',
        ),
        findsNothing,
      );

      await tester.tap(find.text(_dailyQuestion.questionText));
      await tester.pumpAndSettle();

      expect(find.byType(AppHeader), findsNothing);
      expect(find.byType(AppBottomBar), findsOneWidget);
      expect(find.byType(TodayQuestionAnswerScreen), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(_tabs(tester).first.isSelected, isTrue);
    },
  );

  testWidgets(
    '\ub2ec\ub825 \ud0ed\uc758 \ub0a0\uc9dc \uc9c8\ubb38 route\ub97c \uc5f0\ub2e4',
    (tester) async {
      await _pumpApp(
        tester,
        question: _dailyQuestion,
        todayAnswerState: pendingAnswerState,
      );

      GoRouter.of(
        tester.element(find.byType(AppHeader)),
      ).go('/calendar/question?date=2026-05-30');
      await tester.pumpAndSettle();

      expect(find.byType(AppHeader), findsNothing);
      expect(find.byType(AppBottomBar), findsOneWidget);
      expect(find.byType(TodayQuestionAnswerScreen), findsOneWidget);
      expect(find.text('history question'), findsOneWidget);
      expect(_tabs(tester)[1].isSelected, isTrue);
    },
  );

  testWidgets(
    '\uae30\uc874 \uce90\ub9ad\ud130 \uacbd\ub85c\ub97c \uc124\uc815 \uce90\ub9ad\ud130 \uacbd\ub85c\ub85c \uc774\ub3d9\ud55c\ub2e4',
    (tester) async {
      await _pumpApp(
        tester,
        question: _dailyQuestion,
        todayAnswerState: pendingAnswerState,
      );

      final router = GoRouter.of(tester.element(find.byType(AppHeader)));
      router.go('/home/character');
      await tester.pumpAndSettle();

      expect(find.byType(CharacterEditorScreen), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/settings/character',
      );
    },
  );
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
  displayName: '\uc5f0\uc778',
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
