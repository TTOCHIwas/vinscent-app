import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../settings/presentation/widgets/settings_page_layout.dart';
import '../application/ai_direct_question_controller.dart';
import '../data/ai_direct_question_history.dart';
import 'widgets/ai_direct_question_entry_view.dart';
import 'widgets/ai_learning_error_message.dart';

class AiDirectQuestionScreen extends ConsumerWidget {
  const AiDirectQuestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(aiDirectQuestionControllerProvider);

    return SettingsPageLayout(
      title: '지난 질문',
      onBackPressed: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go('/ai');
      },
      child: history.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textPrimary,
          ),
        ),
        error: (error, stackTrace) => _QuestionHistoryError(
          message: aiLearningErrorMessage(error),
          onRetry: () => ref.invalidate(aiDirectQuestionControllerProvider),
        ),
        data: (value) => _QuestionHistoryList(
          history: value,
          onRefresh: () =>
              ref.read(aiDirectQuestionControllerProvider.notifier).refresh(),
          onDelete: (questionId) => _deleteQuestion(context, ref, questionId),
        ),
      ),
    );
  }

  Future<void> _deleteQuestion(
    BuildContext context,
    WidgetRef ref,
    String questionId,
  ) async {
    try {
      await ref
          .read(aiDirectQuestionControllerProvider.notifier)
          .deleteQuestion(questionId);
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

class _QuestionHistoryList extends StatelessWidget {
  const _QuestionHistoryList({
    required this.history,
    required this.onRefresh,
    required this.onDelete,
  });

  final AiDirectQuestionHistory history;
  final RefreshCallback onRefresh;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (history.questions.isEmpty) {
      return RefreshIndicator(
        color: AppColors.textPrimary,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: WordBoundaryText(
                '아직 지난 질문은 없어',
                textAlign: TextAlign.center,
                style: AppTextStyles.homeBody,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.textPrimary,
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: history.questions.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: AppColors.settingsDivider),
        itemBuilder: (context, index) {
          final question = history.questions[index];
          return AiDirectQuestionHistoryEntry(
            key: ValueKey(question.id),
            entry: question,
            onDelete: () => onDelete(question.id),
          );
        },
      ),
    );
  }
}

class _QuestionHistoryError extends StatelessWidget {
  const _QuestionHistoryError({required this.message, required this.onRetry});

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
