import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/application/ai_question_feedback_provider.dart';
import 'package:vinscent/features/ai/data/ai_focused_question_flow.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/ai/data/ai_learning_repository.dart';

void main() {
  test('does not request feedback before both members consent', () async {
    final repository = _FeedbackRepository(
      dashboard: _dashboard(isEnabled: false),
    );
    final container = ProviderContainer(
      overrides: [aiLearningRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final provider = aiQuestionFeedbackProvider('daily-question-id');
    final subscription = container.listen(
      provider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final feedbackState = await container.read(provider.future);

    expect(feedbackState, isA<AiQuestionFeedbackDisabled>());
    expect(repository.dashboardRequestCount, 1);
    expect(repository.feedbackRequestCount, 0);
  });

  test('reports processing while enabled feedback is not published', () async {
    final repository = _FeedbackRepository(
      dashboard: _dashboard(isEnabled: true),
    );
    final container = ProviderContainer(
      overrides: [aiLearningRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final provider = aiQuestionFeedbackProvider('daily-question-id');
    final subscription = container.listen(
      provider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final feedbackState = await container.read(provider.future);

    expect(feedbackState, isA<AiQuestionFeedbackProcessing>());
    expect(repository.dashboardRequestCount, 1);
    expect(repository.feedbackRequestCount, 1);
  });

  test('stops polling after published feedback is returned', () async {
    final publishedFeedback = AiQuestionFeedback(
      dailyQuestionId: 'daily-question-id',
      feedbackText: '함께 대화를 이어가는 방식이 잘 맞아요.',
      publishedAt: DateTime.utc(2026, 7, 20),
    );
    final repository = _FeedbackRepository(
      dashboard: _dashboard(isEnabled: true),
      feedback: publishedFeedback,
    );
    final container = ProviderContainer(
      overrides: [aiLearningRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final provider = aiQuestionFeedbackProvider('daily-question-id');
    final subscription = container.listen(
      provider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final feedbackState = await container.read(provider.future);

    expect(feedbackState, isA<AiQuestionFeedbackPublished>());
    expect(
      (feedbackState as AiQuestionFeedbackPublished).feedback,
      same(publishedFeedback),
    );
    expect(repository.dashboardRequestCount, 1);
    expect(repository.feedbackRequestCount, 1);
  });
}

class _FeedbackRepository implements AiLearningRepository {
  _FeedbackRepository({required this.dashboard, this.feedback});

  final AiLearningDashboard dashboard;
  final AiQuestionFeedback? feedback;
  var dashboardRequestCount = 0;
  var feedbackRequestCount = 0;

  @override
  Future<AiLearningDashboard> fetchDashboard() async {
    dashboardRequestCount += 1;
    return dashboard;
  }

  @override
  Future<AiQuestionFeedback?> fetchQuestionFeedback(
    String dailyQuestionId,
  ) async {
    feedbackRequestCount += 1;
    return feedback;
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

  @override
  Future<void> confirmMemory({
    required String memoryId,
    required AiMemoryDecision decision,
  }) async {}

  @override
  Future<void> setMyConsent({required bool granted}) async {}
}

AiLearningDashboard _dashboard({required bool isEnabled}) {
  return AiLearningDashboard(
    progress: AiLearningProgress(
      curriculumVersion: 1,
      completedCount: 24,
      totalCount: 24,
      stage: AiLearningStage.ready,
      domainProgress: const {},
      myConsent: isEnabled ? AiConsentStatus.granted : AiConsentStatus.revoked,
      partnerConsent: isEnabled
          ? AiConsentStatus.granted
          : AiConsentStatus.revoked,
      isEnabled: isEnabled,
      foundationComplete: true,
      memoryProcessingComplete: true,
      personalizationStatus: isEnabled
          ? AiPersonalizationStatus.ready
          : AiPersonalizationStatus.collecting,
      personalizationEnabled: isEnabled,
      myPendingReviewCount: 0,
      partnerPendingReviewCount: 0,
    ),
    memories: const [],
  );
}
