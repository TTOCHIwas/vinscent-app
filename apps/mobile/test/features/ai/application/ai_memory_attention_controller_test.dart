import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/application/ai_memory_attention_controller.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/ai/data/ai_memory_attention.dart';
import 'package:vinscent/features/ai/data/ai_memory_attention_repository.dart';

void main() {
  test('acknowledges only reviewable pending memories and refreshes', () async {
    final repository = _FakeAiMemoryAttentionRepository();
    final container = ProviderContainer(
      overrides: [
        aiMemoryAttentionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(aiMemoryAttentionControllerProvider.future);
    await container
        .read(aiMemoryAttentionControllerProvider.notifier)
        .acknowledgeVisibleMemories([
          _memory(id: 'pending', canConfirm: true),
          _memory(id: 'waiting', canConfirm: false),
          _memory(id: 'active', canConfirm: false, state: AiMemoryState.active),
        ]);

    expect(repository.acknowledgedTargets.map((target) => target.memoryId), [
      'pending',
    ]);
    expect(
      container.read(aiMemoryAttentionControllerProvider).value,
      const AiMemoryAttentionState.empty(),
    );
  });
}

class _FakeAiMemoryAttentionRepository implements AiMemoryAttentionRepository {
  List<AiMemoryAttentionTarget> acknowledgedTargets = const [];

  @override
  Future<int> acknowledgeMemories(
    List<AiMemoryAttentionTarget> memories,
  ) async {
    acknowledgedTargets = List.unmodifiable(memories);
    return memories.length;
  }

  @override
  Future<AiMemoryAttentionState> fetchState() async {
    return acknowledgedTargets.isEmpty
        ? const AiMemoryAttentionState(unseenMemoryCount: 1)
        : const AiMemoryAttentionState.empty();
  }
}

AiMemory _memory({
  required String id,
  required bool canConfirm,
  AiMemoryState state = AiMemoryState.pending,
}) {
  return AiMemory(
    id: id,
    scope: AiMemoryScope.couple,
    isMine: false,
    kind: 'shared_pattern',
    statement: id,
    confidence: 0.8,
    state: state,
    confirmedCount: 0,
    requiredConfirmationCount: 2,
    canConfirm: canConfirm,
    evidenceCount: 2,
    createdAt: DateTime.utc(2026, 9, 5),
    updatedAt: DateTime.utc(2026, 9, 5, 1),
  );
}
