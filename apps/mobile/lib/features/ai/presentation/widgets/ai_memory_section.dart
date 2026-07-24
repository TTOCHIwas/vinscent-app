import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_action_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../data/ai_learning_dashboard.dart';

typedef AiMemoryDecisionCallback =
    Future<void> Function(AiMemory memory, AiMemoryDecision decision);

class AiMemorySection extends StatelessWidget {
  const AiMemorySection({
    super.key,
    required this.memories,
    required this.onDecision,
    this.pendingReviewCount,
  });

  final List<AiMemory> memories;
  final AiMemoryDecisionCallback onDecision;
  final int? pendingReviewCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text('이렇게 기억했어', style: AppTextStyles.sectionTitle),
            ),
            if (pendingReviewCount case final count?) ...[
              const SizedBox(width: 12),
              Text(
                '확인할 기억 $count개',
                key: const Key('ai-memory-pending-count'),
                style: AppTextStyles.homeCharacterLabel.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (memories.isEmpty)
          Text(
            '지금 확인할 기억은 없어',
            style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
          )
        else
          for (var index = 0; index < memories.length; index++) ...[
            _MemoryRow(
              key: ValueKey('ai-memory-row-${memories[index].id}'),
              memory: memories[index],
              onDecision: onDecision,
            ),
            if (index < memories.length - 1)
              const Divider(height: 1, color: AppColors.settingsDivider),
          ],
      ],
    );
  }
}

class _MemoryRow extends StatefulWidget {
  const _MemoryRow({super.key, required this.memory, required this.onDecision});

  final AiMemory memory;
  final AiMemoryDecisionCallback onDecision;

  @override
  State<_MemoryRow> createState() => _MemoryRowState();
}

class _MemoryRowState extends State<_MemoryRow> {
  AiMemoryDecision? _pendingDecision;

  @override
  Widget build(BuildContext context) {
    final memory = widget.memory;
    final isSubmitting = _pendingDecision != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      _memorySubjectLabel(memory),
                      style: AppTextStyles.homeCharacterLabel.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    WordBoundaryText(
                      memory.statement,
                      style: AppTextStyles.homeBody,
                    ),
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
            ],
          ),
          if (memory.canConfirm) ...[
            const SizedBox(height: 16),
            AppActionButton(
              key: Key('ai-memory-confirm-${memory.id}'),
              label: '맞아',
              enabled: !isSubmitting,
              isLoading: _pendingDecision == AiMemoryDecision.confirmed,
              onPressed: () => _submitDecision(AiMemoryDecision.confirmed),
            ),
            const SizedBox(height: 10),
            AppActionButton(
              key: Key('ai-memory-reject-${memory.id}'),
              label: '아니야',
              enabled: !isSubmitting,
              isLoading: _pendingDecision == AiMemoryDecision.rejected,
              isSecondary: true,
              onPressed: () => _submitDecision(AiMemoryDecision.rejected),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitDecision(AiMemoryDecision decision) async {
    if (_pendingDecision != null) {
      return;
    }

    setState(() {
      _pendingDecision = decision;
    });

    try {
      await widget.onDecision(widget.memory, decision);
    } finally {
      if (mounted) {
        setState(() {
          _pendingDecision = null;
        });
      }
    }
  }
}

String _memorySubjectLabel(AiMemory memory) {
  if (memory.scope == AiMemoryScope.couple) {
    return '둘에 대해';
  }
  return memory.isMine ? '너에 대해' : '상대에 대해';
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
