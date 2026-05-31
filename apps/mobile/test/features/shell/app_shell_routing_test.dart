import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/app/app.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/questions/application/today_question_controller.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_repository.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/shell/presentation/widgets/shell_tab.dart';

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
        ],
        child: const VinscentApp(),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('달력'));
    await tester.pumpAndSettle();
    expect(find.text('달력'), findsNWidgets(2));

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
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

    expect(find.text('답변 저장'), findsOneWidget);

    final tabs = tester.widgetList<ShellTab>(find.byType(ShellTab)).toList();
    expect(tabs.first.isSelected, isTrue);
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

final _activeCouple = Couple(
  id: 'couple-id',
  inviteCode: 'ABC234',
  userAId: 'user-id',
  userBId: 'partner-id',
  relationshipStartDate: DateTime(2026),
  timezone: 'Asia/Seoul',
  status: CoupleStatus.active,
  connectedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
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
