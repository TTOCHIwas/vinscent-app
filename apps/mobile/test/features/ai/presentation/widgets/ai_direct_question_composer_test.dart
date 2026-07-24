import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_keyboard_accessory.dart';
import 'package:vinscent/core/presentation/widgets/word_boundary_text.dart';
import 'package:vinscent/features/ai/data/ai_direct_question_history.dart';
import 'package:vinscent/features/ai/data/ai_direct_question_repository.dart';
import 'package:vinscent/features/ai/presentation/ai_direct_question_composer_controller.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_direct_question_composer.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_direct_question_keyboard_accessory.dart';

void main() {
  testWidgets('shows the guide latest answer and history action', (
    tester,
  ) async {
    var historyPressed = false;
    final repository = _FakeDirectQuestionRepository(
      history: _history(questions: [_completedQuestion]),
    );

    await _pump(
      tester,
      repository,
      onHistoryPressed: () => historyPressed = true,
    );

    expect(
      find.byKey(const Key('ai-direct-question-composer')),
      findsOneWidget,
    );
    final guideCharacter = find.byKey(const Key('ai-direct-guide-character'));
    expect(guideCharacter, findsOneWidget);
    expect(tester.getSize(guideCharacter), const Size.square(156));
    await tester.ensureVisible(find.byKey(const Key('ai-direct-history-open')));
    expect(_wordBoundaryText('나에게 궁금한 걸 물어봐!'), findsOneWidget);
    expect(_wordBoundaryText('가볍게 걸으며 이야기하는 시간이 잘 어울려'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-direct-history-open')));
    expect(historyPressed, isTrue);
  });

  testWidgets('cycles the guide prompt and daily remaining count', (
    tester,
  ) async {
    await _pump(tester, _FakeDirectQuestionRepository(history: _history()));

    expect(_wordBoundaryText('나에게 궁금한 걸 물어봐!'), findsOneWidget);
    expect(find.byKey(const Key('ai-direct-remaining-count')), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(_wordBoundaryText('오늘 2번 더 물어볼 수 있어'), findsOneWidget);
    expect(find.byKey(const Key('ai-direct-remaining-count')), findsOneWidget);
  });

  testWidgets('keeps the exhausted guide message fixed', (tester) async {
    await _pump(
      tester,
      _FakeDirectQuestionRepository(history: _history(remainingCount: 0)),
    );

    expect(_wordBoundaryText('오늘 질문은 모두 사용했어! 내일 다시 물어봐!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();

    expect(_wordBoundaryText('오늘 질문은 모두 사용했어! 내일 다시 물어봐!'), findsOneWidget);
    expect(_wordBoundaryText('나에게 궁금한 걸 물어봐!'), findsNothing);
  });

  testWidgets('keeps input focus when the keyboard inset changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await _pump(tester, _FakeDirectQuestionRepository(history: _history()));

    final input = find.descendant(
      of: find.byKey(const Key('ai-direct-question-input')),
      matching: find.byType(TextField),
    );
    final editableText = find.descendant(
      of: input,
      matching: find.byType(EditableText),
    );

    expect(find.byKey(const Key('ai-direct-keyboard-accessory')), findsNothing);
    expect(find.byKey(const Key('ai-direct-submit')), findsNothing);

    await tester.tap(input);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.enterText(input, '우리에게 물어볼 게 있어');
    await tester.pump();

    expect(
      tester.widget<EditableText>(editableText).focusNode.hasFocus,
      isTrue,
    );
    final accessory = find.byKey(const Key('ai-direct-keyboard-accessory'));
    expect(accessory, findsOneWidget);
    expect(tester.getRect(accessory).bottom, 400);
    expect(
      find.descendant(of: accessory, matching: find.text('13 / 300')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: accessory,
        matching: find.byKey(const Key('ai-direct-submit')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: accessory, matching: find.byType(IconButton)),
      findsNothing,
    );
    expect(find.text('물어보기'), findsOneWidget);
  });

  testWidgets('submits a question from the keyboard accessory', (tester) async {
    addTearDown(tester.view.resetViewInsets);
    final repository = _FakeDirectQuestionRepository(history: _history());
    await _pump(tester, repository);

    final input = find.descendant(
      of: find.byKey(const Key('ai-direct-question-input')),
      matching: find.byType(TextField),
    );
    await tester.tap(input);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.enterText(input, '이번 주말에는 어떤 시간을 보내면 좋을까?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-direct-submit')));
    await tester.pump();
    await tester.pump();

    expect(repository.submittedQuestions, ['이번 주말에는 어떤 시간을 보내면 좋을까?']);
    expect(tester.widget<TextField>(input).controller?.text, isEmpty);
    expect(find.byKey(const Key('ai-direct-keyboard-accessory')), findsNothing);
  });

  testWidgets(
    'shows the character thinking while the latest answer is pending',
    (tester) async {
      await _pump(
        tester,
        _FakeDirectQuestionRepository(
          history: _history(
            questions: [
              AiDirectQuestionEntry(
                id: 'pending-question',
                questionText: '생각 중인 질문',
                status: AiDirectQuestionStatus.processing,
                answerText: null,
                failureCode: null,
                createdAt: DateTime.utc(2026, 7, 24),
                answeredAt: null,
              ),
            ],
          ),
        ),
        settle: false,
      );

      expect(_wordBoundaryText('답을 생각하는 중'), findsOneWidget);
      expect(
        find.byKey(const Key('ai-direct-answer-thinking-dots')),
        findsOneWidget,
      );
    },
  );

  testWidgets('wraps content without overflow at a large text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      _FakeDirectQuestionRepository(
        history: _history(questions: [_completedQuestion]),
      ),
      textScaleFactor: 1.8,
    );

    expect(tester.takeException(), isNull);
  });
}

Finder _wordBoundaryText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is WordBoundaryText && widget.text == text,
  );
}

Future<void> _pump(
  WidgetTester tester,
  AiDirectQuestionRepository repository, {
  VoidCallback? onHistoryPressed,
  double textScaleFactor = 1,
  bool settle = true,
}) async {
  final composerController = AiDirectQuestionComposerController();
  addTearDown(composerController.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiDirectQuestionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        ),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: composerController.focusNode,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AiDirectQuestionComposer(
                controller: composerController,
                onHistoryPressed: onHistoryPressed ?? () {},
              ),
            ),
            builder: (context, child) => AppKeyboardAccessoryLayout(
              isActive: composerController.focusNode.hasFocus,
              accessory: AiDirectQuestionKeyboardAccessory(
                controller: composerController,
              ),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

AiDirectQuestionHistory _history({
  List<AiDirectQuestionEntry> questions = const [],
  int remainingCount = 2,
}) {
  return AiDirectQuestionHistory(
    dailyLimit: 3,
    remainingCount: remainingCount,
    questions: questions,
  );
}

final _completedQuestion = AiDirectQuestionEntry(
  id: 'completed-question',
  questionText: '우리 둘은 쉬는 날에 뭘 하면 잘 맞을까?',
  status: AiDirectQuestionStatus.completed,
  answerText: '가볍게 걸으며 이야기하는 시간이 잘 어울려',
  failureCode: null,
  createdAt: DateTime.utc(2026, 7, 24),
  answeredAt: DateTime.utc(2026, 7, 24, 0, 1),
);

class _FakeDirectQuestionRepository implements AiDirectQuestionRepository {
  _FakeDirectQuestionRepository({required this.history});

  AiDirectQuestionHistory history;
  final List<String> submittedQuestions = [];

  @override
  Future<void> deleteQuestion(String questionId) async {}

  @override
  Future<AiDirectQuestionHistory> fetchHistory() async => history;

  @override
  Future<void> submitQuestion(String questionText) async {
    submittedQuestions.add(questionText);
    history = AiDirectQuestionHistory(
      dailyLimit: history.dailyLimit,
      remainingCount: history.remainingCount - 1,
      questions: history.questions,
    );
  }
}
