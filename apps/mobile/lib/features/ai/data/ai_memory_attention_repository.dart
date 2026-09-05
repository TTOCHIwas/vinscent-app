import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'ai_learning_failure.dart';
import 'ai_memory_attention.dart';

typedef AiMemoryAttentionRpc =
    Future<Object?> Function(
      String functionName,
      Map<String, Object?>? parameters,
    );

final aiMemoryAttentionRepositoryProvider =
    Provider<AiMemoryAttentionRepository>((ref) {
      return const SupabaseAiMemoryAttentionRepository();
    });

abstract interface class AiMemoryAttentionRepository {
  Future<AiMemoryAttentionState> fetchState();

  Future<int> acknowledgeMemories(List<AiMemoryAttentionTarget> memories);
}

class SupabaseAiMemoryAttentionRepository
    implements AiMemoryAttentionRepository {
  const SupabaseAiMemoryAttentionRepository({AiMemoryAttentionRpc? rpc})
    : _rpcOverride = rpc;

  final AiMemoryAttentionRpc? _rpcOverride;

  @override
  Future<AiMemoryAttentionState> fetchState() async {
    final data = await _rpc('get_ai_memory_attention_state');
    try {
      return AiMemoryAttentionState.fromJson(data);
    } on FormatException catch (error) {
      throw AiLearningRepositoryException(
        AiLearningFailureReason.invalidResponse,
        error.message,
      );
    }
  }

  @override
  Future<int> acknowledgeMemories(
    List<AiMemoryAttentionTarget> memories,
  ) async {
    if (memories.isEmpty) {
      return 0;
    }

    final data = await _rpc(
      'acknowledge_ai_memories',
      parameters: {
        'requested_memories': memories
            .map((memory) => memory.toJson())
            .toList(growable: false),
      },
    );
    if (data is num && data >= 0 && data == data.round()) {
      return data.toInt();
    }

    throw const AiLearningRepositoryException(
      AiLearningFailureReason.invalidResponse,
    );
  }

  Future<Object?> _rpc(
    String functionName, {
    Map<String, Object?>? parameters,
  }) async {
    final override = _rpcOverride;
    if (override != null) {
      return override(functionName, parameters);
    }
    if (!AppConfig.isSupabaseConfigured) {
      throw const AiLearningRepositoryException(
        AiLearningFailureReason.configMissing,
      );
    }

    try {
      return await Supabase.instance.client
          .rpc(functionName, params: parameters)
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const AiLearningRepositoryException(
        AiLearningFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw AiLearningRepositoryException(
        AiLearningFailureReason.unknown,
        error.message,
      );
    }
  }
}
