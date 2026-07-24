import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_direct_question_history.dart';
import '../data/ai_direct_question_repository.dart';

final aiDirectQuestionControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AiDirectQuestionController,
      AiDirectQuestionHistory
    >(AiDirectQuestionController.new, retry: (_, _) => null);

class AiDirectQuestionController
    extends AsyncNotifier<AiDirectQuestionHistory> {
  Timer? _pollTimer;
  bool _isRefreshing = false;

  @override
  Future<AiDirectQuestionHistory> build() async {
    ref.onDispose(_cancelPolling);
    final history = await ref
        .read(aiDirectQuestionRepositoryProvider)
        .fetchHistory();
    _updatePolling(history);
    return history;
  }

  Future<void> refresh() async {
    if (_isRefreshing) {
      return;
    }
    _isRefreshing = true;
    try {
      final history = await ref
          .read(aiDirectQuestionRepositoryProvider)
          .fetchHistory();
      state = AsyncValue.data(history);
      _updatePolling(history);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> submitQuestion(String questionText) async {
    await ref
        .read(aiDirectQuestionRepositoryProvider)
        .submitQuestion(questionText);
    await refresh();
  }

  Future<void> deleteQuestion(String questionId) async {
    await ref
        .read(aiDirectQuestionRepositoryProvider)
        .deleteQuestion(questionId);
    await refresh();
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
