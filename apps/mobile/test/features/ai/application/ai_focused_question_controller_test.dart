import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/application/ai_focused_question_controller.dart';
import 'package:vinscent/features/ai/data/ai_focused_question_flow.dart';
import 'package:vinscent/features/ai/data/ai_focused_question_history_entry.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/ai/data/ai_learning_repository.dart';

void main() {
  test('loads a focused question and advances after submitting', () async {
    final repository = _FocusedRepository([
      _flow(position: 1, myAnsweredCount: 0),
      _flow(position: 2, myAnsweredCount: 1),
    ]);
    final container = ProviderContainer(
      overrides: [aiLearningRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final initial = await container.read(
      aiFocusedQuestionControllerProvider.future,
    );
    expect(initial.question?.curriculumPosition, 1);

    await container
        .read(aiFocusedQuestionControllerProvider.notifier)
        .submitAnswer(questionId: 'question-1', answerText: '첫 번째 답변');

    expect(repository.submissions, [('question-1', '첫 번째 답변')]);
    expect(
      container
          .read(aiFocusedQuestionControllerProvider)
          .value
          ?.question
          ?.curriculumPosition,
      2,
    );
  });
}

class _FocusedRepository implements AiLearningRepository {
  _FocusedRepository(this.flows);

  final List<AiFocusedQuestionFlow> flows;
  final submissions = <(String, String)>[];
  var _flowIndex = 0;

  @override
  Future<AiFocusedQuestionFlow> fetchFocusedQuestionFlow() async {
    final index = _flowIndex.clamp(0, flows.length - 1);
    _flowIndex += 1;
    return flows[index];
  }

  @override
  Future<List<AiFocusedQuestionHistoryEntry>>
  fetchFocusedQuestionHistory() async {
    return const [];
  }

  @override
  Future<AiFocusedQuestionFlow> submitFocusedQuestionAnswer({
    required String questionId,
    required String answerText,
  }) async {
    submissions.add((questionId, answerText));
    return fetchFocusedQuestionFlow();
  }

  @override
  Future<AiFocusedQuestionFlow> unlockFocusedQuestions() {
    return fetchFocusedQuestionFlow();
  }

  @override
  Future<AiLearningDashboard> fetchDashboard() {
    throw UnimplementedError();
  }

  @override
  Future<void> setMyConsent({required bool granted}) async {}

  @override
  Future<void> confirmMemory({
    required String memoryId,
    required AiMemoryDecision decision,
  }) async {}

  @override
  Future<AiQuestionFeedback?> fetchQuestionFeedback(
    String dailyQuestionId,
  ) async {
    return null;
  }
}

AiFocusedQuestionFlow _flow({
  required int position,
  required int myAnsweredCount,
}) {
  return AiFocusedQuestionFlow(
    status: AiFocusedQuestionStatus.answering,
    progress: AiFocusedQuestionProgress(
      curriculumVersion: 1,
      myAnsweredCount: myAnsweredCount,
      partnerAnsweredCount: 0,
      coupleCompletedCount: 0,
      totalCount: 24,
    ),
    question: AiFocusedQuestion(
      id: 'question-$position',
      key: 'question_$position',
      text: '질문 $position',
      learningDomain: 'daily_life',
      depth: 'light',
      curriculumPosition: position,
      partnerAnswered: false,
    ),
  );
}
