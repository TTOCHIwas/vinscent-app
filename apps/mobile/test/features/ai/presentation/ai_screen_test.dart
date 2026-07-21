import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/application/ai_learning_controller.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/ai/presentation/ai_screen.dart';

void main() {
  testWidgets('shows consent entry before the current member opts in', (
    tester,
  ) async {
    await _pump(tester, _dashboard(myConsent: AiConsentStatus.revoked));

    expect(find.text('우리 둘의 AI'), findsOneWidget);
    expect(find.byKey(const Key('ai-consent-start')), findsOneWidget);
    expect(find.text('AI 학습 시작하기'), findsOneWidget);
    expect(find.byKey(const Key('ai-learning-progress')), findsOneWidget);
  });

  testWidgets('shows partner waiting state after one member consents', (
    tester,
  ) async {
    await _pump(tester, _dashboard(partnerConsent: AiConsentStatus.revoked));

    expect(find.text('상대방 동의 대기 중'), findsOneWidget);
    expect(find.byKey(const Key('ai-consent-start')), findsNothing);
  });

  testWidgets('keeps memory candidates hidden while foundation is collecting', (
    tester,
  ) async {
    await _pump(tester, _dashboard(memories: [_memory]));

    expect(find.text('8 / 24'), findsOneWidget);
    expect(find.text('함께 산책하는 시간을 좋아해요.'), findsNothing);
    expect(find.text('24개의 답변이 모이면 기억을 함께 확인할 수 있어'), findsOneWidget);
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

    expect(find.text('24 / 24'), findsOneWidget);
    expect(find.text('함께 산책하는 시간을 좋아해요.'), findsOneWidget);
    expect(
      find.byKey(const Key('ai-memory-confirm-memory-id')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-memory-reject-memory-id')), findsOneWidget);
    expect(find.text('맞아'), findsOneWidget);
    expect(find.text('아니야'), findsOneWidget);
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
      ),
    );

    expect(find.text('상대방이 기억을 확인하는 중'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, AiLearningDashboard dashboard) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiLearningControllerProvider.overrideWithBuild(
          (ref, notifier) async => dashboard,
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: AiScreen())),
    ),
  );
  await tester.pumpAndSettle();
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
    memories: memories,
  );
}

final _memory = AiMemory(
  id: 'memory-id',
  scope: AiMemoryScope.couple,
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
