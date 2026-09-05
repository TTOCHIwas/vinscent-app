import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_learning_dashboard.dart';
import '../data/ai_memory_attention.dart';
import '../data/ai_memory_attention_repository.dart';

final aiMemoryAttentionControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AiMemoryAttentionController,
      AiMemoryAttentionState
    >(AiMemoryAttentionController.new, retry: (_, _) => null);

class AiMemoryAttentionController
    extends AsyncNotifier<AiMemoryAttentionState> {
  @override
  Future<AiMemoryAttentionState> build() {
    return ref.read(aiMemoryAttentionRepositoryProvider).fetchState();
  }

  Future<void> refresh() async {
    final previousState = state;
    final refreshedState = await AsyncValue.guard(
      () => ref.read(aiMemoryAttentionRepositoryProvider).fetchState(),
    );
    state = refreshedState.hasError ? previousState : refreshedState;
  }

  Future<void> acknowledgeVisibleMemories(Iterable<AiMemory> memories) async {
    final targets = <String, AiMemoryAttentionTarget>{};
    for (final memory in memories) {
      if (memory.state != AiMemoryState.pending || !memory.canConfirm) {
        continue;
      }
      targets[memory.id] = AiMemoryAttentionTarget(
        memoryId: memory.id,
        memoryUpdatedAt: memory.updatedAt,
      );
    }
    if (targets.isEmpty) {
      return;
    }

    try {
      await ref
          .read(aiMemoryAttentionRepositoryProvider)
          .acknowledgeMemories(targets.values.toList(growable: false));
      await refresh();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ai] Memory attention acknowledgement failed: $error');
      }
    }
  }
}
