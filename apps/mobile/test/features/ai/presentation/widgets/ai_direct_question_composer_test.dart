import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_keyboard_accessory.dart';
import 'package:vinscent/core/presentation/widgets/app_keyboard_dismiss_scope.dart';
import 'package:vinscent/core/presentation/widgets/word_boundary_text.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/ai/data/ai_direct_question_history.dart';
import 'package:vinscent/features/ai/data/ai_direct_question_repository.dart';
import 'package:vinscent/features/ai/presentation/ai_direct_question_composer_controller.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_direct_question_composer.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_direct_question_keyboard_accessory.dart';
import 'package:vinscent/features/characters/presentation/widgets/couple_character_avatar.dart';
import 'package:vinscent/features/safety/data/safety_report.dart';
import 'package:vinscent/features/safety/data/safety_report_repository.dart';

void main() {
  testWidgets('shows only the current exchange when a question exists', (
    tester,
  ) async {
    final repository = _FakeDirectQuestionRepository(
      history: _history(questions: [_completedQuestion]),
    );

    await _pump(tester, repository);

    expect(
      find.byKey(const Key('ai-direct-question-composer')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-direct-guide-character')), findsNothing);
    expect(find.byType(CoupleCharacterAvatar), findsOneWidget);
    expect(
      tester
          .widget<CoupleCharacterAvatar>(
            find.byKey(
              const Key('ai-direct-answer-character-completed-question'),
            ),
          )
          .size,
      216,
    );
    expect(_wordBoundaryText('우리 둘은 쉬는 날에 뭘 하면 잘 맞을까?'), findsOneWidget);
    expect(_wordBoundaryText('가볍게 걸으며 이야기하는 시간이 잘 어울려'), findsOneWidget);
    expect(find.text('최근 답변'), findsNothing);
    expect(
      find.byKey(const Key('ai-generated-content-indicator')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-direct-history-open')), findsNothing);
  });

  testWidgets('opens the report flow from a generated direct answer', (
    tester,
  ) async {
    final safetyRepository = _FakeSafetyReportRepository();
    await _pump(
      tester,
      _FakeDirectQuestionRepository(
        history: _history(questions: [_completedQuestion]),
      ),
      safetyReportRepository: safetyRepository,
    );

    await tester.tap(find.byKey(const Key('ai-generated-content-indicator')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-report-reason-unsafeAi')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('safety-report-submit')));
    await tester.tap(find.byKey(const Key('safety-report-submit')));
    await tester.pumpAndSettle();

    expect(
      safetyRepository.requests.single.target,
      const SafetyReportTarget(
        type: SafetyReportTargetType.aiDirectAnswer,
        id: 'completed-question',
      ),
    );
  });

  testWidgets('opens the report flow from a generated follow-up', (
    tester,
  ) async {
    final safetyRepository = _FakeSafetyReportRepository();
    await _pump(
      tester,
      _FakeDirectQuestionRepository(
        history: _history(questions: [_questionWithPendingFollowUp]),
      ),
      safetyReportRepository: safetyRepository,
    );

    await tester.tap(find.byKey(const Key('ai-generated-content-indicator')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-report-reason-unsafeAi')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('safety-report-submit')));
    await tester.tap(find.byKey(const Key('safety-report-submit')));
    await tester.pumpAndSettle();

    expect(
      safetyRepository.requests.single.target,
      const SafetyReportTarget(
        type: SafetyReportTargetType.aiDirectAnswer,
        id: 'completed-question',
      ),
    );
  });

  testWidgets('shows vertically separated follow-up decision actions', (
    tester,
  ) async {
    final repository = _FakeDirectQuestionRepository(
      history: _history(questions: [_questionWithPendingFollowUp]),
    );
    await _pump(tester, repository);

    final approve = find.byKey(
      const Key('ai-direct-follow-up-approve-completed-question'),
    );
    final dismiss = find.byKey(
      const Key('ai-direct-follow-up-dismiss-completed-question'),
    );
    expect(
      tester
          .widget<CoupleCharacterAvatar>(
            find.byKey(
              const Key('ai-direct-answer-character-completed-question'),
            ),
          )
          .size,
      216,
    );
    await tester.ensureVisible(dismiss);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ai-direct-follow-up-question-completed-question')),
      findsOneWidget,
    );
    expect(approve, findsOneWidget);
    expect(dismiss, findsOneWidget);
    expect(
      find.byKey(const Key('ai-generated-content-indicator')),
      findsOneWidget,
    );
    expect(
      tester.getRect(approve).bottom,
      lessThan(tester.getRect(dismiss).top),
    );

    await tester.tap(approve);
    await tester.pump();
    await tester.pump();

    expect(repository.followUpDecisions, [
      ('completed-question', AiDirectQuestionFollowUpDecision.approve),
    ]);
  });

  testWidgets('shows one idle character before the first question', (
    tester,
  ) async {
    await _pump(tester, _FakeDirectQuestionRepository(history: _history()));

    expect(_wordBoundaryText('우리 둘에 관해 궁금한 걸 물어봐'), findsOneWidget);
    expect(find.byKey(const Key('ai-direct-guide-character')), findsOneWidget);
    expect(find.byType(CoupleCharacterAvatar), findsOneWidget);
  });

  testWidgets('sizes the primary character from the available height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await _pump(tester, _FakeDirectQuestionRepository(history: _history()));

    final character = find.byKey(const Key('ai-direct-guide-character'));
    final input = find.descendant(
      of: find.byKey(const Key('ai-direct-question-input')),
      matching: find.byType(TextField),
    );

    expect(tester.widget<CoupleCharacterAvatar>(character).size, 220);

    await tester.tap(input);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    expect(tester.widget<CoupleCharacterAvatar>(character).size, 132);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    expect(tester.widget<CoupleCharacterAvatar>(character).size, 220);
  });

  testWidgets('uses the exhausted state in the fixed input', (tester) async {
    await _pump(
      tester,
      _FakeDirectQuestionRepository(history: _history(remainingCount: 0)),
    );

    final input = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('ai-direct-question-input')),
        matching: find.byType(TextField),
      ),
    );
    expect(input.enabled, isFalse);
    expect(input.decoration?.hintText, '오늘 질문은 모두 사용했어');
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
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('ai-direct-submit')),
        matching: find.byIcon(Icons.arrow_upward_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('물어보기'), findsOneWidget);
    expect(
      find.descendant(of: accessory, matching: find.text('물어보기')),
      findsNothing,
    );
    final submitButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('ai-direct-submit')),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      submitButton.style?.backgroundColor?.resolve({}),
      AppColors.brandAction,
    );
  });

  testWidgets('scrolls the conversation without dismissing the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await _pump(
      tester,
      _FakeDirectQuestionRepository(
        history: _history(questions: [_completedQuestion]),
      ),
    );

    final input = find.descendant(
      of: find.byKey(const Key('ai-direct-question-input')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(input).minLines, 3);

    await tester.tap(input);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    final inputDock = tester.widget<Padding>(
      find.byKey(const Key('ai-direct-question-input-dock')),
    );

    expect(
      find.byKey(const Key('ai-direct-question-conversation')),
      findsOneWidget,
    );
    expect(find.byType(CoupleCharacterAvatar), findsOneWidget);
    expect(tester.widget<TextField>(input).minLines, 1);
    expect(tester.widget<TextField>(input).maxLines, 3);
    expect((inputDock.padding as EdgeInsets).bottom, 8);

    final editableText = tester.widget<EditableText>(
      find.descendant(of: input, matching: find.byType(EditableText)),
    );
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('ai-direct-question-conversation')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.drag(
      find.byKey(const Key('ai-direct-question-content')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(editableText.focusNode.hasFocus, isTrue);
    expect(scrollable.position.pixels, greaterThan(0));

    final character = find.byType(CoupleCharacterAvatar);
    expect(
      tester.getRect(character).bottom,
      lessThanOrEqualTo(tester.getRect(input).top),
    );
  });

  testWidgets('restores the dock after the keyboard closes', (tester) async {
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

    await tester.tap(input);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    var inputDock = tester.widget<Padding>(
      find.byKey(const Key('ai-direct-question-input-dock')),
    );
    expect((inputDock.padding as EdgeInsets).bottom, 8);
    expect(tester.widget<TextField>(input).minLines, 1);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    inputDock = tester.widget<Padding>(
      find.byKey(const Key('ai-direct-question-input-dock')),
    );
    expect((inputDock.padding as EdgeInsets).bottom, 104);
    expect(tester.widget<TextField>(input).minLines, 3);
  });

  testWidgets('dismisses the keyboard after a completed content tap', (
    tester,
  ) async {
    await _pump(tester, _FakeDirectQuestionRepository(history: _history()));

    final input = find.descendant(
      of: find.byKey(const Key('ai-direct-question-input')),
      matching: find.byType(TextField),
    );
    final editableText = tester.widget<EditableText>(
      find.descendant(of: input, matching: find.byType(EditableText)),
    );

    await tester.tap(input);
    await tester.pump();
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('ai-direct-question-content')));
    await tester.pump();

    expect(editableText.focusNode.hasFocus, isFalse);
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
                resultKind: null,
                answerText: null,
                followUp: null,
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
      expect(
        tester
            .widget<CoupleCharacterAvatar>(
              find.byKey(
                const Key('ai-direct-answer-character-pending-question'),
              ),
            )
            .size,
        216,
      );
      expect(
        find.byKey(const Key('ai-generated-content-indicator')),
        findsNothing,
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
        history: _history(questions: [_questionWithPendingFollowUp]),
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
  SafetyReportRepository? safetyReportRepository,
  double textScaleFactor = 1,
  bool settle = true,
}) async {
  final composerController = AiDirectQuestionComposerController();
  addTearDown(composerController.dispose);
  final composer = AiDirectQuestionComposer(controller: composerController);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiDirectQuestionRepositoryProvider.overrideWithValue(repository),
        if (safetyReportRepository != null)
          safetyReportRepositoryProvider.overrideWithValue(
            safetyReportRepository,
          ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        ),
        home: SizedBox(
          width: 400,
          height: 700,
          child: AppKeyboardDismissScope(
            child: Scaffold(
              body: ListenableBuilder(
                listenable: composerController.focusNode,
                child: composer,
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
  resultKind: AiDirectQuestionResultKind.answered,
  answerText: '가볍게 걸으며 이야기하는 시간이 잘 어울려',
  followUp: null,
  failureCode: null,
  createdAt: DateTime.utc(2026, 7, 24),
  answeredAt: DateTime.utc(2026, 7, 24, 0, 1),
);

final _questionWithPendingFollowUp = AiDirectQuestionEntry(
  id: 'completed-question',
  questionText: '상대는 쉬는 날에 뭘 하고 싶어 할까?',
  status: AiDirectQuestionStatus.completed,
  resultKind: AiDirectQuestionResultKind.insufficient,
  answerText: '아직은 잘 모르겠어',
  followUp: const AiDirectQuestionFollowUp(
    id: 'follow-up-1',
    questionText: '쉬는 날 함께 해보고 싶은 건 뭐야?',
    status: AiDirectQuestionFollowUpStatus.pending,
    sharedQuestionId: null,
  ),
  failureCode: null,
  createdAt: DateTime.utc(2026, 7, 24),
  answeredAt: DateTime.utc(2026, 7, 24, 0, 1),
);

class _FakeDirectQuestionRepository implements AiDirectQuestionRepository {
  _FakeDirectQuestionRepository({required this.history});

  AiDirectQuestionHistory history;
  final List<String> submittedQuestions = [];
  final followUpDecisions = <(String, AiDirectQuestionFollowUpDecision)>[];

  @override
  Future<void> deleteQuestion(String questionId) async {}

  @override
  Future<AiDirectQuestionHistory> fetchHistory() async => history;

  @override
  Future<void> decideFollowUp(
    String questionId,
    AiDirectQuestionFollowUpDecision decision,
  ) async {
    followUpDecisions.add((questionId, decision));
  }

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

class _FakeSafetyReportRepository implements SafetyReportRepository {
  final List<SafetyReportRequest> requests = [];

  @override
  Future<void> submit(SafetyReportRequest request) async {
    requests.add(request);
  }
}
