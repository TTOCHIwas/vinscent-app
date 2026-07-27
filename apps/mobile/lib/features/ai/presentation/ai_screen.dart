import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_keyboard_accessory.dart';
import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/ai_direct_question_controller.dart';
import '../application/ai_learning_controller.dart';
import '../data/ai_learning_dashboard.dart';
import 'ai_direct_question_composer_controller.dart';
import 'widgets/ai_direct_question_keyboard_accessory.dart';
import 'widgets/ai_learning_dashboard_view.dart';
import 'widgets/ai_learning_error_message.dart';
import 'widgets/ai_tab_header.dart';

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  late final AiDirectQuestionComposerController _questionComposerController;

  @override
  void initState() {
    super.initState();
    _questionComposerController = AiDirectQuestionComposerController();
  }

  @override
  void dispose() {
    _questionComposerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(aiLearningControllerProvider);
    final progress = dashboard.value?.progress;
    final isQuestionReady =
        progress?.isEnabled == true &&
        progress?.personalizationStatus == AiPersonalizationStatus.ready;
    final remainingQuestionCount = isQuestionReady
        ? ref.watch(aiDirectQuestionControllerProvider).value?.remainingCount
        : null;
    final content = dashboard.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, stackTrace) => _AiErrorView(
        message: aiLearningErrorMessage(error),
        onRetry: () => ref.invalidate(aiLearningControllerProvider),
      ),
      data: (data) => AiLearningDashboardView(
        dashboard: data,
        directQuestionComposerController: _questionComposerController,
      ),
    );

    return Column(
      children: [
        AiTabHeader(
          isQuestionReady: isQuestionReady,
          remainingQuestionCount: remainingQuestionCount,
          onHistoryPressed: isQuestionReady
              ? () => context.push('/ai/ask')
              : null,
          onMemoryPressed: isQuestionReady
              ? () => context.push('/ai/memories')
              : null,
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _questionComposerController.focusNode,
            child: content,
            builder: (context, child) => AppKeyboardAccessoryLayout(
              isActive: _questionComposerController.focusNode.hasFocus,
              accessory: AiDirectQuestionKeyboardAccessory(
                controller: _questionComposerController,
              ),
              child: child!,
            ),
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
