import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/widgets/app_action_button.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/ai_learning_controller.dart';
import '../../data/ai_learning_dashboard.dart';
import 'ai_learning_error_message.dart';
import 'ai_memory_section.dart';

class AiLearningDashboardView extends ConsumerWidget {
  const AiLearningDashboardView({super.key, required this.dashboard});

  final AiLearningDashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.textPrimary,
      onRefresh: () =>
          ref.read(aiLearningControllerProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 128),
        children: [
          _LearningProgressSection(progress: dashboard.progress),
          const SizedBox(height: 32),
          _ConsentSection(progress: dashboard.progress),
          if (dashboard.progress.isEnabled) ...[
            if (!dashboard.progress.foundationComplete) ...[
              const SizedBox(height: 40),
              _FocusedQuestionSection(dashboard: dashboard),
            ],
            const SizedBox(height: 40),
            _PersonalizationSection(
              progress: dashboard.progress,
              memories: dashboard.memories,
              onDecision: (memory, decision) => _runAction(
                context,
                () => ref
                    .read(aiLearningControllerProvider.notifier)
                    .confirmMemory(memoryId: memory.id, decision: decision),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FocusedQuestionSection extends ConsumerWidget {
  const _FocusedQuestionSection({required this.dashboard});

  final AiLearningDashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnlocked = dashboard.hasFeature(AiFeatureKeys.focusedQuestions);

    return Column(
      key: const Key('ai-focused-question-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '집중 질문',
          style: AppTextStyles.homeBodyMedium.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 8),
        WordBoundaryText(
          isUnlocked
              ? '남은 질문을 기다리지 않고 이어서 답할 수 있어'
              : '24개의 질문을 기다리지 않고 차례로 답할 수 있어',
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: Key(isUnlocked ? 'ai-focused-continue' : 'ai-focused-unlock'),
            onPressed: () => isUnlocked
                ? context.push('/ai/focused')
                : _unlock(context, ref),
            icon: Icon(
              isUnlocked
                  ? Icons.arrow_forward_rounded
                  : Icons.lock_open_rounded,
              size: 20,
            ),
            label: Text(isUnlocked ? '이어서 답하기' : '잠금 해제'),
          ),
        ),
      ],
    );
  }

  Future<void> _unlock(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(aiLearningControllerProvider.notifier)
          .unlockFocusedQuestions();
      if (context.mounted) {
        context.push('/ai/focused');
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(aiLearningErrorMessage(error))));
    }
  }
}

class _PersonalizationSection extends StatelessWidget {
  const _PersonalizationSection({
    required this.progress,
    required this.memories,
    required this.onDecision,
  });

  final AiLearningProgress progress;
  final List<AiMemory> memories;
  final AiMemoryDecisionCallback onDecision;

  @override
  Widget build(BuildContext context) {
    return switch (progress.personalizationStatus) {
      AiPersonalizationStatus.collecting => const _PersonalizationMessage(
        icon: Icons.lock_clock_outlined,
        message: '24개의 답변이 모이면 기억을 함께 확인할 수 있어',
      ),
      AiPersonalizationStatus.processing => const _PersonalizationMessage(
        icon: Icons.auto_awesome_outlined,
        message: '답변에서 기억을 정리하는 중',
      ),
      AiPersonalizationStatus.processingError => const _PersonalizationMessage(
        icon: Icons.error_outline_rounded,
        message: '기억을 정리하지 못했어. 잠시 후 다시 확인해 줘',
      ),
      AiPersonalizationStatus.reviewing => AiMemorySection(
        memories: memories,
        onDecision: onDecision,
      ),
      AiPersonalizationStatus.waitingPartner => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PersonalizationMessage(
            icon: Icons.hourglass_top_rounded,
            message: '상대방이 기억을 확인하는 중',
          ),
          if (memories.isNotEmpty) ...[
            const SizedBox(height: 28),
            AiMemorySection(memories: memories, onDecision: onDecision),
          ],
        ],
      ),
      AiPersonalizationStatus.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PersonalizationMessage(
            icon: Icons.check_circle_outline_rounded,
            message: '우리 둘의 AI가 준비됐어',
          ),
          if (memories.isNotEmpty) ...[
            const SizedBox(height: 28),
            AiMemorySection(memories: memories, onDecision: onDecision),
          ],
        ],
      ),
    };
  }
}

class _PersonalizationMessage extends StatelessWidget {
  const _PersonalizationMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _StatusLine(icon: icon, label: message);
  }
}

class _LearningProgressSection extends StatelessWidget {
  const _LearningProgressSection({required this.progress});

  final AiLearningProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('ai-learning-progress'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: WordBoundaryText(
                _stageLabel(progress.stage),
                style: AppTextStyles.homeBodyMedium,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${progress.completedCount} / ${progress.totalCount}',
              style: AppTextStyles.homeBodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: progress.completionRatio,
            color: AppColors.textPrimary,
            backgroundColor: AppColors.settingsIconBackground,
          ),
        ),
      ],
    );
  }
}

class _ConsentSection extends ConsumerWidget {
  const _ConsentSection({required this.progress});

  final AiLearningProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (progress.myConsent == AiConsentStatus.revoked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '서로의 답변을 바탕으로 우리 둘에게 맞는 기억을 만듭니다.',
            style: AppTextStyles.homeBody,
          ),
          const SizedBox(height: 20),
          AppActionButton(
            key: const Key('ai-consent-start'),
            label: 'AI 학습 시작하기',
            enabled: true,
            onPressed: () => _showConsentSheet(context, ref),
          ),
        ],
      );
    }

    if (!progress.isEnabled) {
      return const _StatusLine(
        icon: Icons.hourglass_top_rounded,
        label: '상대방 동의 대기 중',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StatusLine(
          icon: Icons.check_circle_outline_rounded,
          label: '함께 학습 중',
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _showRevokeDialog(context, ref),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.textMuted,
          ),
          child: const Text('AI 학습 중지'),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.textPrimary),
        const SizedBox(width: 10),
        Expanded(
          child: WordBoundaryText(label, style: AppTextStyles.homeBodyMedium),
        ),
      ],
    );
  }
}

Future<void> _showConsentSheet(BuildContext context, WidgetRef ref) async {
  final shouldGrant = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 학습 안내',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '두 사람이 모두 동의하면 질문과 답변을 Google Gemini로 분석해 개인과 커플의 기억 후보를 만듭니다. 기억은 확인한 뒤에만 활성화되며 언제든 학습을 중지할 수 있습니다.',
                style: AppTextStyles.homeBody.copyWith(
                  color: AppColors.textMuted,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              AppActionButton(
                label: '동의하고 시작',
                enabled: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (shouldGrant != true || !context.mounted) {
    return;
  }

  await _runAction(
    context,
    () => ref
        .read(aiLearningControllerProvider.notifier)
        .setConsent(granted: true),
  );
}

Future<void> _showRevokeDialog(BuildContext context, WidgetRef ref) async {
  final shouldRevoke = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('AI 학습을 중지할까요?'),
      content: const Text('새로운 답변 분석과 기억 생성을 중지합니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('중지'),
        ),
      ],
    ),
  );

  if (shouldRevoke != true || !context.mounted) {
    return;
  }

  await _runAction(
    context,
    () => ref
        .read(aiLearningControllerProvider.notifier)
        .setConsent(granted: false),
  );
}

Future<void> _runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(aiLearningErrorMessage(error))));
  }
}

String _stageLabel(AiLearningStage stage) {
  return switch (stage) {
    AiLearningStage.collecting => '서로를 알아가는 중',
    AiLearningStage.exploring => '대화의 결을 찾는 중',
    AiLearningStage.refining => '우리 둘을 정리하는 중',
    AiLearningStage.ready => '24개의 답변 완료',
  };
}
