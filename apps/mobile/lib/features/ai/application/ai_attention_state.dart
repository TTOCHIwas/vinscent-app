import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_memory_attention_controller.dart';

class AiAttentionState {
  const AiAttentionState({required this.unseenMemoryCount});

  const AiAttentionState.empty() : unseenMemoryCount = 0;

  final int unseenMemoryCount;

  bool get hasUnseenMemory => unseenMemoryCount > 0;
}

final aiAttentionStateProvider = Provider<AiAttentionState>((ref) {
  final attention = ref
      .watch(aiMemoryAttentionControllerProvider)
      .asData
      ?.value;
  if (attention == null) {
    return const AiAttentionState.empty();
  }

  return AiAttentionState(unseenMemoryCount: attention.unseenMemoryCount);
});
