import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_typography.dart';
import '../../settings/presentation/widgets/settings_page_layout.dart';
import '../application/ai_learning_controller.dart';
import '../data/ai_learning_dashboard.dart';
import 'widgets/ai_learning_error_message.dart';

class AiMemoryScreen extends ConsumerWidget {
  const AiMemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(aiLearningControllerProvider);

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
        loading: () => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textPrimary,
          ),
        ),
        error: (error, stackTrace) => _MemoryLoadError(
          message: aiLearningErrorMessage(error),
          onRetry: () => ref.invalidate(aiLearningControllerProvider),
        ),
        data: (value) => _ConfirmedMemoryList(
          memories: value.confirmedMemories,
          onRefresh: () =>
              ref.read(aiLearningControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _ConfirmedMemoryList extends StatelessWidget {
  const _ConfirmedMemoryList({required this.memories, required this.onRefresh});

  final List<AiMemory> memories;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty) {
      return RefreshIndicator(
        color: AppColors.textPrimary,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: WordBoundaryText(
                '아직 확인된 기억은 없어',
                textAlign: TextAlign.center,
                style: AppTextStyles.homeBody,
              ),
            ),
          ],
        ),
      );
    }

    final myMemories = memories
        .where(
          (memory) => memory.scope == AiMemoryScope.personal && memory.isMine,
        )
        .toList(growable: false);
    final partnerMemories = memories
        .where(
          (memory) => memory.scope == AiMemoryScope.personal && !memory.isMine,
        )
        .toList(growable: false);
    final coupleMemories = memories
        .where((memory) => memory.scope == AiMemoryScope.couple)
        .toList(growable: false);

    return RefreshIndicator(
      color: AppColors.textPrimary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
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
            child: WordBoundaryText(
              memories[index].statement,
              style: AppTextStyles.homeBody,
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
