import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_direct_question_history.dart';
import '../data/ai_direct_question_repository.dart';
import 'ai_async_operation_queue.dart';

final aiDirectQuestionControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AiDirectQuestionController,
      AiDirectQuestionHistory
    >(AiDirectQuestionController.new, retry: (_, _) => null);

class AiDirectQuestionController
    extends AsyncNotifier<AiDirectQuestionHistory> {
  Timer? _pollTimer;
  final _operations = AiAsyncOperationQueue();

  @override
  Future<AiDirectQuestionHistory> build() async {
    ref.onDispose(_cancelPolling);
    final history = await ref
        .read(aiDirectQuestionRepositoryProvider)
        .fetchHistory();
    _updatePolling(history);
    return history;
  }

  Future<void> refresh() {
    return _operations.run(_reload);
  }

  Future<void> submitQuestion(String questionText) {
    return _operations.run(() async {
      await ref
          .read(aiDirectQuestionRepositoryProvider)
          .submitQuestion(questionText);
      await _reload();
    });
  }

  Future<void> deleteQuestion(String questionId) {
    return _operations.run(() async {
      await ref
          .read(aiDirectQuestionRepositoryProvider)
          .deleteQuestion(questionId);
      await _reload();
    });
  }

  Future<void> _reload() async {
    final history = await ref
        .read(aiDirectQuestionRepositoryProvider)
        .fetchHistory();
    state = AsyncValue.data(history);
    _updatePolling(history);
  }

  void _updatePolling(AiDirectQuestionHistory history) {
    if (!history.hasPendingQuestion) {
      _cancelPolling();
      return;
    }
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_refreshFromPolling()),
    );
  }

  Future<void> _refreshFromPolling() async {
    try {
      await refresh();
    } on Object {
      debugPrint('[ai] direct question polling failed');
    }
  }

  void _cancelPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
