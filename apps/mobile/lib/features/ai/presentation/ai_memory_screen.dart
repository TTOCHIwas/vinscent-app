import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_typography.dart';
import '../../settings/presentation/widgets/settings_page_layout.dart';
import '../application/ai_memory_attention_controller.dart';
import '../application/ai_learning_controller.dart';
import '../data/ai_learning_dashboard.dart';
import '../data/ai_memory_attention.dart';
import 'widgets/ai_learning_error_message.dart';
import 'widgets/ai_learning_stop_button.dart';
import 'widgets/ai_memory_generated_indicator.dart';
import 'widgets/ai_memory_section.dart';

class AiMemoryScreen extends ConsumerStatefulWidget {
  const AiMemoryScreen({super.key});

  @override
  ConsumerState<AiMemoryScreen> createState() => _AiMemoryScreenState();
}

class _AiMemoryScreenState extends ConsumerState<AiMemoryScreen> {
  String? _scheduledAttentionSignature;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(aiLearningControllerProvider);
    final attention = ref.watch(aiMemoryAttentionControllerProvider);

    return SettingsPageLayout(
      title: '기억한 내용',
      onBackPressed: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go('/ai');
      },
      child: dashboard.when(
        loading: () => const Center(child: AppLoadingIndicator(strokeWidth: 2)),
        error: (error, stackTrace) => _MemoryLoadError(
          message: aiLearningErrorMessage(error),
          onRetry: () => ref.invalidate(aiLearningControllerProvider),
        ),
        data: (value) {
          _scheduleAttentionAcknowledgement(value, attention.value);
          return _MemoryList(
            dashboard: value,
            onDecision: _confirmMemory,
            onRefresh: () async {
              await Future.wait([
                ref.read(aiLearningControllerProvider.notifier).refresh(),
                ref
                    .read(aiMemoryAttentionControllerProvider.notifier)
                    .refresh(),
              ]);
            },
          );
        },
      ),
    );
  }

  void _scheduleAttentionAcknowledgement(
    AiLearningDashboard dashboard,
    AiMemoryAttentionState? attention,
  ) {
    if (attention?.hasUnseenMemory != true) {
      return;
    }

    final pendingMemories = dashboard.memories
        .where((memory) => memory.canConfirm)
        .toList(growable: false);
    if (pendingMemories.isEmpty) {
      return;
    }

    final signature = pendingMemories
        .map(
          (memory) =>
              '${memory.id}:${memory.updatedAt.toUtc().toIso8601String()}',
        )
        .join('|');
    if (_scheduledAttentionSignature == signature) {
      return;
    }
    _scheduledAttentionSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref
            .read(aiMemoryAttentionControllerProvider.notifier)
            .acknowledgeVisibleMemories(pendingMemories),
      );
    });
  }

  Future<void> _confirmMemory(
    AiMemory memory,
    AiMemoryDecision decision,
  ) async {
    try {
      await ref
          .read(aiLearningControllerProvider.notifier)
          .confirmMemory(memoryId: memory.id, decision: decision);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(aiLearningErrorMessage(error))));
    }
  }
}

class _MemoryList extends StatelessWidget {
  const _MemoryList({
    required this.dashboard,
    required this.onDecision,
    required this.onRefresh,
  });

  final AiLearningDashboard dashboard;
  final AiMemoryDecisionCallback onDecision;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final pendingMemories = dashboard.memories
        .where((memory) => memory.canConfirm)
        .toList(growable: false);
    final confirmedMemories = dashboard.confirmedMemories;
    if (pendingMemories.isEmpty && confirmedMemories.isEmpty) {
      return RefreshIndicator(
        color: AppColors.textMuted,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            const Center(
              child: WordBoundaryText(
                '아직 확인된 기억은 없어',
                textAlign: TextAlign.center,
                style: AppTextStyles.homeBody,
              ),
            ),
            const SizedBox(height: 40),
            const Align(
              alignment: Alignment.centerLeft,
              child: AiLearningStopButton(key: Key('ai-learning-stop')),
            ),
          ],
        ),
      );
    }

    final myMemories = confirmedMemories
        .where(
          (memory) => memory.scope == AiMemoryScope.personal && memory.isMine,
        )
        .toList(growable: false);
    final partnerMemories = confirmedMemories
        .where(
          (memory) => memory.scope == AiMemoryScope.personal && !memory.isMine,
        )
        .toList(growable: false);
    final coupleMemories = confirmedMemories
        .where((memory) => memory.scope == AiMemoryScope.couple)
        .toList(growable: false);

    return RefreshIndicator(
      color: AppColors.textMuted,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (pendingMemories.isNotEmpty) ...[
            AiMemorySection(
              key: const Key('ai-memory-pending-section'),
              memories: pendingMemories,
              pendingReviewCount: dashboard.progress.myPendingReviewCount,
              onDecision: onDecision,
            ),
            if (confirmedMemories.isNotEmpty) const SizedBox(height: 36),
          ],
          if (myMemories.isNotEmpty)
            _MemoryGroup(title: '너에 대해', memories: myMemories),
          if (partnerMemories.isNotEmpty) ...[
            if (myMemories.isNotEmpty) const SizedBox(height: 28),
            _MemoryGroup(title: '상대에 대해', memories: partnerMemories),
          ],
          if (coupleMemories.isNotEmpty) ...[
            if (myMemories.isNotEmpty || partnerMemories.isNotEmpty)
              const SizedBox(height: 28),
            _MemoryGroup(title: '둘에 대해', memories: coupleMemories),
          ],
          const SizedBox(height: 36),
          const Align(
            alignment: Alignment.centerLeft,
            child: AiLearningStopButton(key: Key('ai-learning-stop')),
          ),
        ],
      ),
    );
  }
}

class _MemoryGroup extends StatelessWidget {
  const _MemoryGroup({required this.title, required this.memories});

  final String title;
  final List<AiMemory> memories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.withFontSize(AppTextStyles.homeBodyMedium, 18),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < memories.length; index++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: WordBoundaryText(
                    memories[index].statement,
                    style: AppTextStyles.homeBody,
                  ),
                ),
                const SizedBox(width: 8),
                AiMemoryGeneratedIndicator(
                  key: ValueKey(
                    'ai-memory-generated-indicator-${memories[index].id}',
                  ),
                  memoryId: memories[index].id,
                ),
              ],
            ),
          ),
          if (index < memories.length - 1)
            const Divider(height: 1, color: AppColors.settingsDivider),
        ],
      ],
    );
  }
}

class _MemoryLoadError extends StatelessWidget {
  const _MemoryLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WordBoundaryText(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeBody,
          ),
          const SizedBox(height: 12),
          IconButton(
            tooltip: '다시 시도',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}
