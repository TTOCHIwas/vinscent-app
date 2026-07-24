import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/word_boundary_text.dart';
import 'package:vinscent/features/ai/application/ai_learning_controller.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/ai/presentation/ai_memory_screen.dart';

void main() {
  testWidgets('groups only confirmed memories for read-only viewing', (
    tester,
  ) async {
    await _pump(tester, [
      _memory(
        id: 'mine',
        statement: '나는 조용한 산책을 좋아해',
        scope: AiMemoryScope.personal,
        isMine: true,
      ),
      _memory(
        id: 'partner',
        statement: '상대는 함께 요리하는 시간을 좋아해',
        scope: AiMemoryScope.personal,
      ),
      _memory(
        id: 'couple',
        statement: '둘은 새로운 장소를 함께 찾는 걸 좋아해',
        scope: AiMemoryScope.couple,
      ),
      _memory(
        id: 'pending',
        statement: '아직 확인하지 않은 기억',
        scope: AiMemoryScope.couple,
        state: AiMemoryState.pending,
      ),
    ]);

    expect(find.text('기억한 내용'), findsOneWidget);
    expect(find.text('너에 대해'), findsOneWidget);
    expect(find.text('상대에 대해'), findsOneWidget);
    expect(find.text('둘에 대해'), findsOneWidget);
    expect(_wordBoundaryText('나는 조용한 산책을 좋아해'), findsOneWidget);
    expect(_wordBoundaryText('상대는 함께 요리하는 시간을 좋아해'), findsOneWidget);
    expect(_wordBoundaryText('둘은 새로운 장소를 함께 찾는 걸 좋아해'), findsOneWidget);
    expect(_wordBoundaryText('아직 확인하지 않은 기억'), findsNothing);
    expect(find.text('확인됨'), findsNothing);
  });

  testWidgets('shows an empty state when there are no confirmed memories', (
    tester,
  ) async {
    await _pump(tester, [
      _memory(
        id: 'pending',
        statement: '아직 확인하지 않은 기억',
        scope: AiMemoryScope.couple,
        state: AiMemoryState.pending,
      ),
    ]);

    expect(_wordBoundaryText('아직 확인된 기억은 없어'), findsOneWidget);
  });
}

Finder _wordBoundaryText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is WordBoundaryText && widget.text == text,
  );
}

Future<void> _pump(WidgetTester tester, List<AiMemory> memories) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiLearningControllerProvider.overrideWithBuild(
          (ref, notifier) async => _dashboard(memories),
        ),
      ],
      child: const MaterialApp(home: AiMemoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

AiLearningDashboard _dashboard(List<AiMemory> memories) {
  return AiLearningDashboard(
    progress: const AiLearningProgress(
      curriculumVersion: 1,
      completedCount: 24,
      totalCount: 24,
      stage: AiLearningStage.ready,
      domainProgress: {},
      myConsent: AiConsentStatus.granted,
      partnerConsent: AiConsentStatus.granted,
      isEnabled: true,
      foundationComplete: true,
      memoryProcessingComplete: true,
      personalizationStatus: AiPersonalizationStatus.ready,
      personalizationEnabled: true,
      myPendingReviewCount: 0,
      partnerPendingReviewCount: 0,
    ),
    memories: memories,
  );
}

AiMemory _memory({
  required String id,
  required String statement,
  required AiMemoryScope scope,
  bool isMine = false,
  AiMemoryState state = AiMemoryState.active,
}) {
  return AiMemory(
    id: id,
    scope: scope,
    isMine: isMine,
    kind: 'preference',
    statement: statement,
    confidence: 0.9,
    state: state,
    confirmedCount: state == AiMemoryState.active ? 2 : 0,
    requiredConfirmationCount: 2,
    canConfirm: false,
    evidenceCount: 2,
    createdAt: DateTime.utc(2026, 7, 24),
    updatedAt: DateTime.utc(2026, 7, 24),
  );
}
