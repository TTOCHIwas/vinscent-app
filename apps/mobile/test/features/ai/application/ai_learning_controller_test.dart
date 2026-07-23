import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/application/ai_learning_controller.dart';
import 'package:vinscent/features/ai/data/ai_focused_question_flow.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/ai/data/ai_learning_repository.dart';

void main() {
  test('loads the dashboard and refreshes it after granting consent', () async {
    final repository = _FakeAiLearningRepository([
      _dashboard(myConsent: AiConsentStatus.revoked),
      _dashboard(
        myConsent: AiConsentStatus.granted,
        partnerConsent: AiConsentStatus.revoked,
      ),
    ]);
    final container = ProviderContainer(
      overrides: [aiLearningRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final initial = await container.read(aiLearningControllerProvider.future);
    expect(initial.progress.myConsent, AiConsentStatus.revoked);

    await container
        .read(aiLearningControllerProvider.notifier)
        .setConsent(granted: true);

    expect(repository.consentUpdates, [true]);
    expect(
      container.read(aiLearningControllerProvider).value?.progress.myConsent,
      AiConsentStatus.granted,
    );
  });

  test('refreshes memories after confirming one', () async {
    final repository = _FakeAiLearningRepository([
      _dashboard(memories: [_pendingMemory]),
      _dashboard(memories: [_activeMemory]),
    ]);
    final container = ProviderContainer(
      overrides: [aiLearningRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(aiLearningControllerProvider.future);
    await container
        .read(aiLearningControllerProvider.notifier)
        .confirmMemory(
          memoryId: 'memory-id',
          decision: AiMemoryDecision.confirmed,
        );

    expect(repository.memoryDecisions, [
      ('memory-id', AiMemoryDecision.confirmed),
    ]);
    expect(
      container.read(aiLearningControllerProvider).value?.memories.single.state,
      AiMemoryState.active,
    );
  });
}

class _FakeAiLearningRepository implements AiLearningRepository {
  _FakeAiLearningRepository(this.dashboards);

  final List<AiLearningDashboard> dashboards;
  final consentUpdates = <bool>[];
  final memoryDecisions = <(String, AiMemoryDecision)>[];
  var _dashboardIndex = 0;

  @override
  Future<AiLearningDashboard> fetchDashboard() async {
    final index = _dashboardIndex.clamp(0, dashboards.length - 1);
    _dashboardIndex += 1;
    return dashboards[index];
  }

  @override
  Future<void> setMyConsent({required bool granted}) async {
    consentUpdates.add(granted);
  }

  @override
  Future<void> confirmMemory({
    required String memoryId,
    required AiMemoryDecision decision,
  }) async {
    memoryDecisions.add((memoryId, decision));
  }

  @override
  Future<AiQuestionFeedback?> fetchQuestionFeedback(
    String dailyQuestionId,
  ) async {
    return null;
  }

  @override
  Future<AiFocusedQuestionFlow> fetchFocusedQuestionFlow() {
    throw UnimplementedError();
  }

  @override
  Future<AiFocusedQuestionFlow> submitFocusedQuestionAnswer({
    required String questionId,
    required String answerText,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AiFocusedQuestionFlow> unlockFocusedQuestions() {
    throw UnimplementedError();
  }
}

AiLearningDashboard _dashboard({
  AiConsentStatus myConsent = AiConsentStatus.granted,
  AiConsentStatus partnerConsent = AiConsentStatus.granted,
  List<AiMemory> memories = const [],
}) {
  return AiLearningDashboard(
    progress: AiLearningProgress(
      curriculumVersion: 1,
      completedCount: 4,
      totalCount: 24,
      stage: AiLearningStage.collecting,
      domainProgress: const {},
      myConsent: myConsent,
      partnerConsent: partnerConsent,
      isEnabled:
          myConsent == AiConsentStatus.granted &&
          partnerConsent == AiConsentStatus.granted,
      foundationComplete: false,
      memoryProcessingComplete: false,
      personalizationStatus: AiPersonalizationStatus.collecting,
      personalizationEnabled: false,
      myPendingReviewCount: 0,
      partnerPendingReviewCount: 0,
    ),
    memories: memories,
  );
}

final _pendingMemory = AiMemory(
  id: 'memory-id',
  scope: AiMemoryScope.personal,
  kind: 'personal_value',
  statement: '함께 있는 조용한 시간을 중요하게 생각해요.',
  confidence: 0.9,
  state: AiMemoryState.pending,
  confirmedCount: 0,
  requiredConfirmationCount: 1,
  canConfirm: true,
  evidenceCount: 1,
  createdAt: DateTime.utc(2026, 7, 20),
  updatedAt: DateTime.utc(2026, 7, 20),
);

final _activeMemory = AiMemory(
  id: 'memory-id',
  scope: AiMemoryScope.personal,
  kind: 'personal_value',
  statement: '함께 있는 조용한 시간을 중요하게 생각해요.',
  confidence: 0.9,
  state: AiMemoryState.active,
  myDecision: AiMemoryDecision.confirmed,
  confirmedCount: 1,
  requiredConfirmationCount: 1,
  canConfirm: false,
  evidenceCount: 1,
  createdAt: DateTime.utc(2026, 7, 20),
  updatedAt: DateTime.utc(2026, 7, 20),
);
