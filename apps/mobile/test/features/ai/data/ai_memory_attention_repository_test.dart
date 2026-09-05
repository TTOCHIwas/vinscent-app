import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/data/ai_memory_attention.dart';
import 'package:vinscent/features/ai/data/ai_memory_attention_repository.dart';

void main() {
  test('fetches the unseen memory count', () async {
    final repository = SupabaseAiMemoryAttentionRepository(
      rpc: (functionName, parameters) async {
        expect(functionName, 'get_ai_memory_attention_state');
        expect(parameters, isNull);
        return {'unseen_memory_count': 2};
      },
    );

    expect(
      await repository.fetchState(),
      const AiMemoryAttentionState(unseenMemoryCount: 2),
    );
  });

  test('acknowledges exact memory versions', () async {
    String? capturedFunction;
    Map<String, Object?>? capturedParameters;
    final repository = SupabaseAiMemoryAttentionRepository(
      rpc: (functionName, parameters) async {
        capturedFunction = functionName;
        capturedParameters = parameters;
        return 2;
      },
    );
    final targets = [
      AiMemoryAttentionTarget(
        memoryId: 'memory-1',
        memoryUpdatedAt: DateTime.utc(2026, 9, 5, 1, 2, 3),
      ),
      AiMemoryAttentionTarget(
        memoryId: 'memory-2',
        memoryUpdatedAt: DateTime.utc(2026, 9, 5, 4, 5, 6),
      ),
    ];

    expect(await repository.acknowledgeMemories(targets), 2);
    expect(capturedFunction, 'acknowledge_ai_memories');
    expect(capturedParameters, {
      'requested_memories': [
        {
          'memory_id': 'memory-1',
          'memory_updated_at': '2026-09-05T01:02:03.000Z',
        },
        {
          'memory_id': 'memory-2',
          'memory_updated_at': '2026-09-05T04:05:06.000Z',
        },
      ],
    });
  });
}
