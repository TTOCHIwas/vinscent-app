import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/application/ai_learning_controller.dart';
import 'package:vinscent/features/ai/application/ai_direct_question_controller.dart';
import 'package:vinscent/features/ai/data/ai_direct_question_history.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/ai/presentation/ai_screen.dart';
import 'package:vinscent/core/presentation/widgets/word_boundary_text.dart';

void main() {
  testWidgets('shows consent entry before the current member opts in', (
    tester,
  ) async {
    await _pump(tester, _dashboard(myConsent: AiConsentStatus.revoked));

    expect(_wordBoundaryText('우리 둘의 AI'), findsOneWidget);
    expect(find.byKey(const Key('ai-consent-start')), findsOneWidget);
    expect(find.text('AI 학습 시작하기'), findsOneWidget);
    expect(find.byKey(const Key('ai-learning-progress')), findsOneWidget);
  });

  testWidgets('shows partner waiting state after one member consents', (
    tester,
  ) async {
    await _pump(tester, _dashboard(partnerConsent: AiConsentStatus.revoked));

    expect(_wordBoundaryText('상대방 동의 대기 중'), findsOneWidget);
    expect(find.byKey(const Key('ai-consent-start')), findsNothing);
  });

  testWidgets('keeps memory candidates hidden while foundation is collecting', (
    tester,
  ) async {
    await _pump(tester, _dashboard(memories: [_memory]));

    expect(find.text('8 / 24'), findsOneWidget);
    expect(_wordBoundaryText('함께 산책하는 시간을 좋아해요.'), findsNothing);
    expect(_wordBoundaryText('24개의 답변이 모이면 기억을 함께 확인할 수 있어'), findsOneWidget);
  });

  testWidgets('shows only yes and no actions during foundation memory review', (
    tester,
  ) async {
    await _pump(
      tester,
      _dashboard(
        completedCount: 24,
        personalizationStatus: AiPersonalizationStatus.reviewing,
        memories: [_memory],
        myPendingReviewCount: 1,
      ),
    );

    expect(find.byKey(const Key('ai-learning-progress')), findsNothing);
    expect(find.text('24 / 24'), findsNothing);
    expect(_wordBoundaryText('함께 산책하는 시간을 좋아해요.'), findsOneWidget);
    expect(
      find.byKey(const Key('ai-memory-confirm-memory-id')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-memory-reject-memory-id')), findsOneWidget);
    expect(find.text('맞아'), findsOneWidget);
    expect(find.text('아니야'), findsOneWidget);

    final confirmRect = tester.getRect(
      find.byKey(const Key('ai-memory-confirm-memory-id')),
    );
    final rejectRect = tester.getRect(
      find.byKey(const Key('ai-memory-reject-memory-id')),
    );

    expect(confirmRect.width, greaterThan(200));
    expect(rejectRect.width, confirmRect.width);
    expect(rejectRect.top - confirmRect.bottom, greaterThanOrEqualTo(8));
  });

  testWidgets('shows at most five actionable memories in one review batch', (
    tester,
  ) async {
    final memories = List.generate(
      6,
      (index) =>
          _memory.copyWith(id: 'memory-$index', statement: '기억 문장 $index'),
    );

    await _pump(
      tester,
      _dashboard(
        completedCount: 24,
        personalizationStatus: AiPersonalizationStatus.reviewing,
        memories: memories,
        myPendingReviewCount: memories.length,
      ),
    );

    expect(find.byKey(const Key('ai-memory-confirm-memory-0')), findsOneWidget);
    expect(find.byKey(const Key('ai-memory-confirm-memory-4')), findsOneWidget);
    expect(find.byKey(const Key('ai-memory-confirm-memory-5')), findsNothing);
    expect(_wordBoundaryText('기억 문장 5'), findsNothing);
    expect(find.text('확인할 기억 6개'), findsOneWidget);
  });

  testWidgets('shows confirmed memories as one compact entry when ready', (
    tester,
  ) async {
    await _pump(
      tester,
      _dashboard(
        completedCount: 24,
        personalizationStatus: AiPersonalizationStatus.ready,
        memories: [
          _memory.copyWith(
            id: 'mine',
            scope: AiMemoryScope.personal,
            subjectUserId: 'current-user',
            isMine: true,
            state: AiMemoryState.active,
            canConfirm: false,
          ),
          _memory.copyWith(
            id: 'partner',
            scope: AiMemoryScope.personal,
            subjectUserId: 'partner-user',
            isMine: false,
            state: AiMemoryState.active,
            canConfirm: false,
          ),
        ],
      ),
    );

    expect(find.byKey(const Key('ai-learning-progress')), findsNothing);
    expect(find.byKey(const Key('ai-memory-summary-open')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('AI 학습 중지'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(_wordBoundaryText('함께 학습 중'), findsNothing);
    expect(_wordBoundaryText('우리 둘의 AI가 준비됐어'), findsNothing);
    expect(find.text('기억한 내용'), findsOneWidget);
    expect(_wordBoundaryText('확인한 기억 2개'), findsOneWidget);
    expect(find.text('AI 학습 중지'), findsOneWidget);
    expect(find.text('너에 대해'), findsNothing);
    expect(find.text('상대에 대해'), findsNothing);
    expect(_wordBoundaryText('함께 산책하는 시간을 좋아해요.'), findsNothing);
  });

  testWidgets('shows partner wait until both reviews are resolved', (
    tester,
  ) async {
    await _pump(
      tester,
      _dashboard(
        completedCount: 24,
        personalizationStatus: AiPersonalizationStatus.waitingPartner,
        partnerPendingReviewCount: 2,
        memories: [_memory],
      ),
    );

    expect(find.byKey(const Key('ai-learning-progress')), findsNothing);
    expect(_wordBoundaryText('상대방이 기억을 확인하는 중'), findsOneWidget);
    expect(_wordBoundaryText('함께 산책하는 시간을 좋아해요.'), findsNothing);
  });

  testWidgets('wraps dashboard status text at a large system text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, _dashboard(), textScaleFactor: 2);

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a permanent unlock action before focused access', (
    tester,
  ) async {
    await _pump(tester, _dashboard());

    expect(find.byKey(const Key('ai-focused-unlock')), findsOneWidget);
    expect(find.byKey(const Key('ai-focused-continue')), findsNothing);
  });

  testWidgets('shows a continue action after focused access is unlocked', (
    tester,
  ) async {
    await _pump(
      tester,
      _dashboard(enabledFeatures: const {AiFeatureKeys.focusedQuestions}),
    );

    expect(find.byKey(const Key('ai-focused-unlock')), findsNothing);
    expect(find.byKey(const Key('ai-focused-continue')), findsOneWidget);
  });

  testWidgets('shows the direct question composer first when ready', (
    tester,
  ) async {
    await _pump(
      tester,
      _dashboard(
        completedCount: 24,
        personalizationStatus: AiPersonalizationStatus.ready,
        memories: [
          _memory.copyWith(state: AiMemoryState.active, canConfirm: false),
        ],
      ),
      directQuestionHistory: _directQuestionHistory(),
    );

    final composer = find.byKey(const Key('ai-direct-question-composer'));
    final memorySummary = find.byKey(const Key('ai-memory-summary-open'));

    expect(composer, findsOneWidget);
    expect(
      find.descendant(
        of: composer,
        matching: find.byKey(const Key('ai-direct-question-input')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-direct-history-open')), findsOneWidget);
    expect(memorySummary, findsOneWidget);
    expect(
      tester.getTopLeft(composer).dy,
      lessThan(tester.getTopLeft(memorySummary).dy),
    );
  });

  testWidgets('shows the direct question action above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await _pump(
      tester,
      _dashboard(
        completedCount: 24,
        personalizationStatus: AiPersonalizationStatus.ready,
      ),
    );

    final input = find.descendant(
      of: find.byKey(const Key('ai-direct-question-input')),
      matching: find.byType(TextField),
    );
    await tester.tap(input);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    final accessory = find.byKey(const Key('ai-direct-keyboard-accessory'));
    final characterCountText = find.descendant(
      of: accessory,
      matching: find.text('0 / 300'),
    );
    final submitText = find.descendant(
      of: accessory,
      matching: find.text('물어보기'),
    );
    expect(accessory, findsOneWidget);
    expect(tester.getRect(accessory).bottom, 400);
    expect(
      tester.getRect(characterCountText).left,
      closeTo(tester.getRect(input).left, 0.5),
    );
    expect(
      tester.getRect(submitText).right,
      closeTo(tester.getRect(input).right, 0.5),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('ai-direct-question-composer')),
        matching: find.byKey(const Key('ai-direct-submit')),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'keeps direct questions locked while personalization is collecting',
    (tester) async {
      await _pump(tester, _dashboard());

      expect(
        find.byKey(const Key('ai-direct-question-composer')),
        findsNothing,
      );
    },
  );
}

Finder _wordBoundaryText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is WordBoundaryText && widget.text == text,
  );
}

Future<void> _pump(
  WidgetTester tester,
  AiLearningDashboard dashboard, {
  double textScaleFactor = 1,
  AiDirectQuestionHistory? directQuestionHistory,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiLearningControllerProvider.overrideWithBuild(
          (ref, notifier) async => dashboard,
        ),
        aiDirectQuestionControllerProvider.overrideWithBuild(
          (ref, notifier) async =>
              directQuestionHistory ?? _directQuestionHistory(),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        ),
        home: const Scaffold(body: AiScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AiDirectQuestionHistory _directQuestionHistory() {
  return AiDirectQuestionHistory(
    dailyLimit: 3,
    remainingCount: 2,
    questions: [
      AiDirectQuestionEntry(
        id: 'direct-question-id',
        questionText: '우리는 쉬는 날에 뭘 하면 잘 맞을까?',
        status: AiDirectQuestionStatus.completed,
        answerText: '가볍게 걸으며 이야기하는 시간이 잘 어울려',
        failureCode: null,
        createdAt: DateTime.utc(2026, 7, 24),
        answeredAt: DateTime.utc(2026, 7, 24, 0, 1),
      ),
    ],
  );
}

AiLearningDashboard _dashboard({
  AiConsentStatus myConsent = AiConsentStatus.granted,
  AiConsentStatus partnerConsent = AiConsentStatus.granted,
  List<AiMemory> memories = const [],
  int completedCount = 8,
  AiPersonalizationStatus personalizationStatus =
      AiPersonalizationStatus.collecting,
  int myPendingReviewCount = 0,
  int partnerPendingReviewCount = 0,
  Set<String> enabledFeatures = const {},
}) {
  return AiLearningDashboard(
    progress: AiLearningProgress(
      curriculumVersion: 1,
      completedCount: completedCount,
      totalCount: 24,
      stage: AiLearningStage.exploring,
      domainProgress: const {},
      myConsent: myConsent,
      partnerConsent: partnerConsent,
      isEnabled:
          myConsent == AiConsentStatus.granted &&
          partnerConsent == AiConsentStatus.granted,
      foundationComplete: completedCount >= 24,
      memoryProcessingComplete: completedCount >= 24,
      personalizationStatus: personalizationStatus,
      personalizationEnabled:
          personalizationStatus == AiPersonalizationStatus.ready,
      myPendingReviewCount: myPendingReviewCount,
      partnerPendingReviewCount: partnerPendingReviewCount,
    ),
    enabledFeatures: enabledFeatures,
    memories: memories,
  );
}

final _memory = AiMemory(
  id: 'memory-id',
  scope: AiMemoryScope.couple,
  isMine: false,
  kind: 'relationship_pattern',
  statement: '함께 산책하는 시간을 좋아해요.',
  confidence: 0.85,
  state: AiMemoryState.pending,
  confirmedCount: 0,
  requiredConfirmationCount: 2,
  canConfirm: true,
  evidenceCount: 2,
  createdAt: DateTime.utc(2026, 7, 20),
  updatedAt: DateTime.utc(2026, 7, 20),
);

extension on AiMemory {
  AiMemory copyWith({
    String? id,
    AiMemoryScope? scope,
    String? subjectUserId,
    bool? isMine,
    String? statement,
    AiMemoryState? state,
    bool? canConfirm,
  }) {
    return AiMemory(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      subjectUserId: subjectUserId ?? this.subjectUserId,
      isMine: isMine ?? this.isMine,
      kind: kind,
      statement: statement ?? this.statement,
      confidence: confidence,
      state: state ?? this.state,
      myDecision: myDecision,
      confirmedCount: confirmedCount,
      requiredConfirmationCount: requiredConfirmationCount,
      canConfirm: canConfirm ?? this.canConfirm,
      evidenceCount: evidenceCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
