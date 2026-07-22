import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/ai_learning_controller.dart';
import 'widgets/ai_learning_dashboard_view.dart';
import 'widgets/ai_learning_error_message.dart';
import 'widgets/ai_tab_header.dart';

class AiScreen extends ConsumerWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(aiLearningControllerProvider);

    return Column(
      children: [
        const AiTabHeader(),
        Expanded(
          child: dashboard.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.textPrimary),
            ),
            error: (error, stackTrace) => _AiErrorView(
              message: aiLearningErrorMessage(error),
              onRetry: () => ref.invalidate(aiLearningControllerProvider),
            ),
            data: (data) => AiLearningDashboardView(dashboard: data),
          ),
        ),
      ],
    );
  }
}

class _AiErrorView extends StatelessWidget {
  const _AiErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.homeBody,
            ),
            const SizedBox(height: 16),
            IconButton(
              tooltip: '다시 시도',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
