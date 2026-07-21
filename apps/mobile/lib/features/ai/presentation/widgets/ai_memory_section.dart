import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/ai_learning_dashboard.dart';

typedef AiMemoryDecisionCallback =
    Future<void> Function(AiMemory memory, AiMemoryDecision decision);

class AiMemorySection extends StatelessWidget {
  const AiMemorySection({
    super.key,
    required this.memories,
    required this.onDecision,
  });

  final List<AiMemory> memories;
  final AiMemoryDecisionCallback onDecision;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI가 정리한 기억',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.4,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        if (memories.isEmpty)
          Text(
            '답변이 쌓이면 확인할 기억이 여기에 나타납니다.',
            style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
          )
        else
          for (var index = 0; index < memories.length; index++) ...[
            _MemoryRow(memory: memories[index], onDecision: onDecision),
            if (index < memories.length - 1)
              const Divider(height: 1, color: AppColors.settingsDivider),
          ],
      ],
    );
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({required this.memory, required this.onDecision});

  final AiMemory memory;
  final AiMemoryDecisionCallback onDecision;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            memory.scope == AiMemoryScope.personal
                ? Icons.person_outline_rounded
                : Icons.favorite_border_rounded,
            size: 22,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memory.scope == AiMemoryScope.personal
                      ? '나에 대한 기억'
                      : '우리 둘의 기억',
                  style: AppTextStyles.homeCharacterLabel.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(memory.statement, style: AppTextStyles.homeBody),
                if (!memory.canConfirm) ...[
                  const SizedBox(height: 8),
                  Text(
                    _memoryStateLabel(memory),
                    style: AppTextStyles.homeCharacterLabel.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (memory.canConfirm) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextButton(
                  key: Key('ai-memory-confirm-${memory.id}'),
                  onPressed: () async {
                    await onDecision(memory, AiMemoryDecision.confirmed);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(56, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('맞아'),
                ),
                TextButton(
                  key: Key('ai-memory-reject-${memory.id}'),
                  onPressed: () async {
                    await onDecision(memory, AiMemoryDecision.rejected);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    minimumSize: const Size(56, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('아니야'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _memoryStateLabel(AiMemory memory) {
  if (memory.isWaitingForPartner) {
    return '상대방 확인 대기';
  }

  return switch (memory.state) {
    AiMemoryState.active => '확인됨',
    AiMemoryState.pending => '확인 대기',
    AiMemoryState.rejected => '기억에서 제외됨',
    AiMemoryState.superseded => '새로운 기억으로 갱신됨',
  };
}
