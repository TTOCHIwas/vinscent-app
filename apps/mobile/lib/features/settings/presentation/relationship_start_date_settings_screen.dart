import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_date_picker_sheet.dart';
import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/relationship_start_date_editor_controller.dart';
import '../../couple/application/relationship_start_date_editor_state.dart';
import '../../couple/presentation/widgets/relationship_start_date_field.dart';
import 'widgets/settings_page_layout.dart';

class RelationshipStartDateSettingsScreen extends ConsumerWidget {
  const RelationshipStartDateSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(relationshipStartDateEditorControllerProvider);

    return SettingsPageLayout(
      title: '만난 날',
      onBackPressed: () => context.pop(),
      action: editor.maybeWhen(
        data: (state) => IconButton(
          key: const Key('relationship-start-date-save'),
          tooltip: '만난 날 저장',
          onPressed: state.canSave ? () => _save(context, ref) : null,
          icon: state.isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
        ),
        orElse: () => null,
      ),
      child: editor.when(
        loading: () => const Center(child: AppLoadingIndicator(strokeWidth: 2)),
        error: (error, stackTrace) => _LoadFailure(
          onRetry: () =>
              ref.invalidate(relationshipStartDateEditorControllerProvider),
        ),
        data: (state) => _RelationshipStartDateEditor(
          state: state,
          onDatePressed: () => _pickDate(context, ref, state),
        ),
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    RelationshipStartDateEditorState state,
  ) async {
    final selectedDate = await showAppDatePickerSheet(
      context: context,
      title: '만난 날 선택',
      initialDate: state.selectedDate,
      minDate: DateTime(1900),
      maxDate: state.latestAllowedDate,
    );
    if (selectedDate != null) {
      ref
          .read(relationshipStartDateEditorControllerProvider.notifier)
          .selectDate(selectedDate);
    }
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final saved = await ref
        .read(relationshipStartDateEditorControllerProvider.notifier)
        .save();
    if (!context.mounted || !saved) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('만난 날을 변경했어요.')));
    context.pop();
  }
}

class _RelationshipStartDateEditor extends StatelessWidget {
  const _RelationshipStartDateEditor({
    required this.state,
    required this.onDatePressed,
  });

  final RelationshipStartDateEditorState state;
  final VoidCallback onDatePressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const Text('처음 만난 날을 알려줘', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 8),
        Text(
          '디데이와 기념일, 캘린더의 시작 기준이 함께 바뀌어',
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        RelationshipStartDateField(
          selectedDate: state.selectedDate,
          onTap: state.isSaving ? null : onDatePressed,
        ),
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
          const Text('만난 날을 불러오지 못했어요.', style: AppTextStyles.homeBodyMedium),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
