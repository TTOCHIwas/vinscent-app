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
import 'package:vinscent/features/shell/presentation/widgets/shell_tab.dart';

import '../../support/couple_fixtures.dart';

void main() {
  testWidgets('shows shell around authenticated home route', (tester) async {
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
          todayControllerProvider.overrideWithBuild(
            (ref, notifier) => DateTime(2026, 5, 31),
          ),
        ],
        child: const VinscentApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('앱 이름'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('달력'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('오늘의 질문'), findsOneWidget);
  });

  testWidgets('moves between shell routes through bottom bar and header', (
    tester,
  ) async {
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
          todayControllerProvider.overrideWithBuild(
            (ref, notifier) => DateTime(2026, 5, 31),
          ),
        ],
        child: const VinscentApp(),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('달력'));
    await tester.pumpAndSettle();
    expect(find.text('앱 이름'), findsNothing);
    expect(find.text('2026년 05월'), findsOneWidget);
    expect(
      tester.widgetList<ShellTab>(find.byType(ShellTab)).elementAt(1).isSelected,
      isTrue,
    );

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.text('앱 이름'), findsOneWidget);
    expect(find.text('AI'), findsNWidgets(2));

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(find.text('설정'), findsNWidgets(2));
  });
  testWidgets('opens today question answer route under home tab', (
    tester,
  ) async {
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
          todayControllerProvider.overrideWithBuild(
            (ref, notifier) => DateTime(2026, 5, 31),
          ),
          todayQuestionControllerProvider.overrideWithBuild(
            (ref, notifier) async => _dailyQuestion,
          ),
          dailyQuestionAnswerRepositoryProvider.overrideWithValue(
            _FakeDailyQuestionAnswerRepository(),
          ),
        ],
        child: const VinscentApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('today question'));
    await tester.pumpAndSettle();

    expect(find.text('앱 이름'), findsNothing);
    expect(find.text('05월 31일'), findsOneWidget);
    expect(find.text('내 답변'), findsOneWidget);

    final tabs = tester.widgetList<ShellTab>(find.byType(ShellTab)).toList();
    expect(tabs.first.isSelected, isTrue);
  });

  testWidgets('opens dated question answer route under calendar tab', (
    tester,
  ) async {
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
          todayControllerProvider.overrideWithBuild(
            (ref, notifier) => DateTime(2026, 5, 31),
          ),
          dailyQuestionHistoryRepositoryProvider.overrideWithValue(
            const _FakeDailyQuestionHistoryRepository(),
          ),
        ],
        child: const VinscentApp(),
      ),
    );

    await tester.pumpAndSettle();
    GoRouter.of(
      tester.element(find.text('오늘의 질문')),
    ).go('/calendar/question?date=2026-05-30');
    await tester.pumpAndSettle();

    expect(find.text('앱이름'), findsNothing);
    expect(find.text('05월 30일'), findsOneWidget);
    expect(find.text('history question'), findsOneWidget);

    final tabs = tester.widgetList<ShellTab>(find.byType(ShellTab)).toList();
    expect(tabs.elementAt(1).isSelected, isTrue);
  });
}

final _profile = UserProfile(
  id: 'user-id',
  displayName: '연인',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _activeCouple = activeCouple(
  relationshipStartDate: DateTime(2026),
);

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

class _FakeDailyQuestionAnswerRepository
    implements DailyQuestionAnswerRepository {
  var currentState = const DailyQuestionAnswerState(
    dailyQuestionId: 'daily-question-id',
    status: DailyQuestionStatus.pending,
    partnerAnswerExists: false,
    answerCount: 0,
  );

  @override
  Future<DailyQuestionAnswerState> fetchTodayAnswerState() async {
    return currentState;
  }

  @override
  Future<DailyQuestionAnswerState> submitTodayAnswer(String answerText) async {
    currentState = DailyQuestionAnswerState(
      dailyQuestionId: 'daily-question-id',
      status: DailyQuestionStatus.answeredByOne,
      myAnswerId: 'answer-id',
      myAnswerText: answerText,
      partnerAnswerExists: false,
      answerCount: 1,
    );

    return currentState;
  }
}

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
