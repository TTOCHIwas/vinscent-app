import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/expressions/data/couple_expression.dart';
import 'package:vinscent/features/expressions/data/couple_expression_repository.dart';
import 'package:vinscent/features/expressions/data/couple_expression_summary.dart';
import 'package:vinscent/features/home/presentation/home_screen.dart';
import 'package:vinscent/features/questions/application/today_question_controller.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_repository.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/question_answer_fixtures.dart';

void main() {
  testWidgets('shows active couple day count and unavailable question copy', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
    );

    expect(find.text('우리'), findsOneWidget);
    expect(find.text('D+2일째', findRichText: true), findsOneWidget);
    expect(find.text('오늘의 질문'), findsOneWidget);
    expect(find.text('오늘 질문이 아직 준비되지 않았어요.'), findsOneWidget);
  });

  testWidgets('shows today question text before any answer is written', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      question: _dailyQuestion,
      answerRepository: FakeDailyQuestionAnswerRepository(pendingAnswerState),
    );

    expect(find.text('오늘의 질문'), findsOneWidget);
    expect(find.text(_dailyQuestion.questionText), findsOneWidget);
  });

  testWidgets('shows today question loading state', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      questionLoading: true,
      settle: false,
    );

    expect(find.text('오늘의 질문'), findsOneWidget);
    expect(find.text('오늘 질문을 불러오고 있어요.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows today question error state', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      questionError: Exception('question failed'),
    );

    expect(find.text('오늘 질문을 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('shows missing couple message', (tester) async {
    await _pumpHome(tester, couple: null, today: _today);

    expect(find.text('커플 정보를 찾을 수 없어요.'), findsOneWidget);
  });

  testWidgets('shows missing relationship start date message', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCoupleWithoutDate,
      today: _today,
    );

    expect(find.text('첫 만난 날을 먼저 입력해주세요.'), findsOneWidget);
  });

  testWidgets('shows partner answered copy before my answer is written', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      question: _dailyQuestion,
      answerRepository: FakeDailyQuestionAnswerRepository(
        partnerAnsweredOnlyState,
      ),
    );

    expect(find.text('상대방은 답변을 남겼어요.'), findsOneWidget);
  });

  testWidgets('shows waiting for partner copy after my answer is written', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      question: _dailyQuestion,
      answerRepository: FakeDailyQuestionAnswerRepository(myAnswerOnlyState()),
    );

    expect(find.text('상대방의 답변을 기다리고 있어요.'), findsOneWidget);
  });

  testWidgets('shows ai placeholder copy when both answers are completed', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      question: _dailyQuestion,
      answerRepository: FakeDailyQuestionAnswerRepository(completedAnswerState),
    );

    expect(find.text('AI 한 줄 평이 여기에 표시될 예정이에요.'), findsOneWidget);
  });

  testWidgets('sends selected expression and shows success feedback', (
    tester,
  ) async {
    final expressionRepository = _FakeCoupleExpressionRepository();

    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      expressionRepository: expressionRepository,
    );

    await tester.ensureVisible(find.byIcon(Icons.thumb_up_alt_outlined));
    await tester.tap(find.byIcon(Icons.thumb_up_alt_outlined));
    await tester.pumpAndSettle();

    expect(expressionRepository.sentTypes, [CoupleExpressionType.thanks]);
    expect(find.text('표현을 보냈어요.'), findsOneWidget);
  });

  testWidgets('shows failure feedback when expression send fails', (
    tester,
  ) async {
    final expressionRepository = _FakeCoupleExpressionRepository(
      shouldFail: true,
    );

    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      expressionRepository: expressionRepository,
    );

    await tester.ensureVisible(
      find.byIcon(Icons.sentiment_dissatisfied_outlined),
    );
    await tester.tap(find.byIcon(Icons.sentiment_dissatisfied_outlined));
    await tester.pumpAndSettle();

    expect(
      expressionRepository.sentTypes,
      [CoupleExpressionType.feelingDown],
    );
    expect(find.text('표현을 보내지 못했어요.'), findsOneWidget);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required Couple? couple,
  required DateTime today,
  DailyQuestion? question,
  Object? questionError,
  bool questionLoading = false,
  bool settle = true,
  CoupleExpressionRepository? expressionRepository,
  DailyQuestionAnswerRepository? answerRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => couple,
        ),
        todayControllerProvider.overrideWithBuild((ref, notifier) => today),
        todayQuestionControllerProvider.overrideWithBuild((ref, notifier) {
          if (questionLoading) {
            return Completer<DailyQuestion?>().future;
          }

          if (questionError != null) {
            throw questionError;
          }

          return question;
        }),
        dailyQuestionAnswerRepositoryProvider.overrideWithValue(
          answerRepository ?? FakeDailyQuestionAnswerRepository(pendingAnswerState),
        ),
        coupleExpressionRepositoryProvider.overrideWithValue(
          expressionRepository ?? _FakeCoupleExpressionRepository(),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _FakeCoupleExpressionRepository implements CoupleExpressionRepository {
  _FakeCoupleExpressionRepository({this.shouldFail = false});

  final bool shouldFail;
  final sentTypes = <CoupleExpressionType>[];

  @override
  Future<CoupleExpression> send(CoupleExpressionType type) async {
    sentTypes.add(type);

    if (shouldFail) {
      throw Exception('expression unavailable');
    }

    return CoupleExpression(
      id: 'expression-id',
      coupleId: 'couple-id',
      senderUserId: 'user-id',
      receiverUserId: 'partner-id',
      type: type,
      sentAt: DateTime(2026, 5, 31, 12),
    );
  }

  @override
  Future<List<CoupleExpressionSummary>> fetchSummaryByDate(
    DateTime date,
  ) async {
    return const [];
  }
}

final _today = DateTime(2026, 5, 31);

final _activeCouple = activeCouple(currentDate: _today);

final _activeCoupleWithoutDate = activeCoupleWithoutDate(currentDate: _today);

final _dailyQuestion = DailyQuestion(
  dailyQuestionId: 'daily-question-id',
  coupleId: 'couple-id',
  questionId: 'question-id',
  questionText: '오늘 서로에게 가장 고마웠던 순간은 언제였어?',
  questionSource: QuestionSource.curated,
  questionCategory: 'daily',
  questionMood: 'warm',
  assignedDate: _today,
  status: DailyQuestionStatus.pending,
);
