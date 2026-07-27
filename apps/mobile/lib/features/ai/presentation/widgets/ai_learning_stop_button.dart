import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_confirmation_sheet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/ai_learning_controller.dart';
import 'ai_learning_error_message.dart';

class AiLearningStopButton extends ConsumerWidget {
  const AiLearningStopButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => _stopLearning(context, ref),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: AppColors.textMuted,
      ),
      child: const Text('AI 학습 중지'),
    );
  }

  Future<void> _stopLearning(BuildContext context, WidgetRef ref) async {
    final shouldStop = await showAppConfirmationSheet(
      context: context,
      title: 'AI 학습을 중지할까요?',
      message: '새로운 답변 분석과 기억 생성을 중지합니다.',
      confirmLabel: '중지',
    );
    if (!shouldStop || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(aiLearningControllerProvider.notifier)
          .setConsent(granted: false);
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
