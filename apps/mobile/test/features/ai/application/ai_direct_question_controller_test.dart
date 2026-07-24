import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/application/ai_direct_question_controller.dart';
import 'package:vinscent/features/ai/data/ai_direct_question_history.dart';
import 'package:vinscent/features/ai/data/ai_direct_question_repository.dart';

void main() {
  test(
    'queues submission behind an active refresh and reloads afterward',
    () async {
      final refreshGate = Completer<AiDirectQuestionHistory>();
      final repository = _QueuedDirectQuestionRepository(refreshGate);
      final container = ProviderContainer(
        overrides: [
          aiDirectQuestionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        aiDirectQuestionControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      await container.read(aiDirectQuestionControllerProvider.future);
      final controller = container.read(
        aiDirectQuestionControllerProvider.notifier,
      );
      final refresh = controller.refresh();
      await repository.refreshStarted.future;

      final submission = controller.submitQuestion('우리에게 물어볼 질문');
      await Future<void>.delayed(Duration.zero);

      expect(repository.submittedQuestions, isEmpty);

      refreshGate.complete(_history());
      await refresh;
      await submission;

      expect(repository.submittedQuestions, ['우리에게 물어볼 질문']);
      expect(repository.fetchCount, 3);
      expect(
        container
            .read(aiDirectQuestionControllerProvider)
            .value
            ?.hasPendingQuestion,
        isTrue,
      );
    },
  );
}

class _QueuedDirectQuestionRepository implements AiDirectQuestionRepository {
  _QueuedDirectQuestionRepository(this.refreshGate);

  final Completer<AiDirectQuestionHistory> refreshGate;
  final refreshStarted = Completer<void>();
  final submittedQuestions = <String>[];
  var fetchCount = 0;

  @override
  Future<AiDirectQuestionHistory> fetchHistory() {
    fetchCount += 1;
    if (fetchCount == 1) {
      return Future.value(_history());
    }
    if (fetchCount == 2) {
      refreshStarted.complete();
      return refreshGate.future;
    }
    return Future.value(
      _history(
        questions: [
          AiDirectQuestionEntry(
            id: 'pending-question',
            questionText: submittedQuestions.single,
            status: AiDirectQuestionStatus.queued,
            answerText: null,
            failureCode: null,
            createdAt: DateTime.utc(2026, 7, 24),
            answeredAt: null,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> submitQuestion(String questionText) async {
    submittedQuestions.add(questionText);
  }

  @override
  Future<void> deleteQuestion(String questionId) {
    throw UnimplementedError();
  }
}

AiDirectQuestionHistory _history({
  List<AiDirectQuestionEntry> questions = const [],
}) {
  return AiDirectQuestionHistory(
    dailyLimit: 3,
    remainingCount: questions.isEmpty ? 3 : 2,
    questions: questions,
  );
}
