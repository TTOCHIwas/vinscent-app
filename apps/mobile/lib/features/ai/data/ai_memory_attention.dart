class AiMemoryAttentionState {
  const AiMemoryAttentionState({required this.unseenMemoryCount});

  const AiMemoryAttentionState.empty() : unseenMemoryCount = 0;

  factory AiMemoryAttentionState.fromJson(Object? data) {
    final row = _asRow(data);
    final rawCount = row['unseen_memory_count'];
    if (rawCount is! num || rawCount < 0 || rawCount != rawCount.round()) {
      throw const FormatException('Invalid unseen memory count');
    }

    return AiMemoryAttentionState(unseenMemoryCount: rawCount.toInt());
  }

  final int unseenMemoryCount;

  bool get hasUnseenMemory => unseenMemoryCount > 0;

  @override
  bool operator ==(Object other) {
    return other is AiMemoryAttentionState &&
        other.unseenMemoryCount == unseenMemoryCount;
  }

  @override
  int get hashCode => unseenMemoryCount.hashCode;
}

class AiMemoryAttentionTarget {
  const AiMemoryAttentionTarget({
    required this.memoryId,
    required this.memoryUpdatedAt,
  });

  final String memoryId;
  final DateTime memoryUpdatedAt;

  Map<String, Object> toJson() {
    return {
      'memory_id': memoryId,
      'memory_updated_at': memoryUpdatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is AiMemoryAttentionTarget &&
        other.memoryId == memoryId &&
        other.memoryUpdatedAt == memoryUpdatedAt;
  }

  @override
  int get hashCode => Object.hash(memoryId, memoryUpdatedAt);
}

Map<String, dynamic> _asRow(Object? data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  if (data is List && data.isNotEmpty) {
    return _asRow(data.first);
  }

  throw const FormatException('Invalid AI memory attention payload');
}
