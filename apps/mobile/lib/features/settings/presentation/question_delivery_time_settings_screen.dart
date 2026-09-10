import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/presentation/widgets/app_time_picker_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/question_delivery_time_editor_controller.dart';
import '../../couple/application/question_delivery_time_editor_state.dart';
import '../../couple/data/question_delivery_time.dart';
import '../../couple/presentation/widgets/question_delivery_time_field.dart';
import 'widgets/settings_page_layout.dart';

class QuestionDeliveryTimeSettingsScreen extends ConsumerWidget {
  const QuestionDeliveryTimeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(questionDeliveryTimeEditorControllerProvider);

    return SettingsPageLayout(
      title: '질문 시간',
      onBackPressed: () => context.pop(),
      action: editor.maybeWhen(
        data: (state) => IconButton(
          key: const Key('question-delivery-time-save'),
          tooltip: '질문 시간 저장',
          color: AppColors.brandAction,
          onPressed: state.canSave ? () => _save(context, ref) : null,
          icon: state.isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandAction,
                  ),
                )
              : const Icon(Icons.check_rounded),
        ),
        orElse: () => null,
      ),
      child: editor.when(
        loading: () => const Center(child: AppLoadingIndicator(strokeWidth: 2)),
        error: (error, stackTrace) => _LoadFailure(
          onRetry: () =>
              ref.invalidate(questionDeliveryTimeEditorControllerProvider),
        ),
        data: (state) => _QuestionDeliveryTimeEditor(
          state: state,
          onTimePressed: () => _pickTime(context, ref, state.selectedTime),
        ),
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    QuestionDeliveryTime selectedTime,
  ) async {
    final pickedTime = await showAppTimePickerSheet(
      context: context,
      title: '질문 받을 시간',
      initialTime: TimeOfDay(
        hour: selectedTime.hour,
        minute: selectedTime.minute,
      ),
    );
    if (pickedTime != null) {
      ref
          .read(questionDeliveryTimeEditorControllerProvider.notifier)
          .selectTime(
            QuestionDeliveryTime(
              hour: pickedTime.hour,
              minute: pickedTime.minute,
            ),
          );
    }
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final saved = await ref
        .read(questionDeliveryTimeEditorControllerProvider.notifier)
        .save();
    if (!context.mounted || !saved) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('다음 날부터 새 질문 시간을 적용해요.')));
    context.pop();
  }
}

class _QuestionDeliveryTimeEditor extends StatelessWidget {
  const _QuestionDeliveryTimeEditor({
    required this.state,
    required this.onTimePressed,
  });

  final QuestionDeliveryTimeEditorState state;
  final VoidCallback onTimePressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const Text('질문 받을 시간을 골라줘', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 8),
        Text(
          '두 사람에게 같은 시간에 질문이 도착하고, 변경한 시간은 다음 날부터 적용돼',
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        QuestionDeliveryTimeField(
          selectedTime: state.selectedTime,
          onTap: state.isSaving ? null : onTimePressed,
        ),
        if (state.pendingEffectiveDate case final effectiveDate?) ...[
          const SizedBox(height: 12),
          Text(
            '${_formatDate(effectiveDate)}부터 ${state.pendingTime?.label ?? state.selectedTime.label}에 질문이 도착해',
            style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
          ),
        ],
        if (state.errorMessage case final errorMessage?) ...[
          const SizedBox(height: 12),
          Text(errorMessage, style: AppTextStyles.compactError),
        ],
      ],
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('질문 시간을 불러오지 못했어요.', style: AppTextStyles.homeBodyMedium),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}
