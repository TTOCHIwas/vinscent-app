import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../profile/application/profile_display_name_editor_controller.dart';
import '../../profile/application/profile_display_name_editor_state.dart';
import '../../profile/presentation/widgets/profile_display_name_field.dart';
import 'widgets/settings_page_layout.dart';

class ProfileDisplayNameSettingsScreen extends ConsumerWidget {
  const ProfileDisplayNameSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(profileDisplayNameEditorControllerProvider);

    return SettingsPageLayout(
      title: '닉네임',
      onBackPressed: () => context.pop(),
      action: editor.maybeWhen(
        data: (state) => IconButton(
          key: const Key('profile-display-name-save'),
          tooltip: '닉네임 저장',
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
              ref.invalidate(profileDisplayNameEditorControllerProvider),
        ),
        data: (state) => _ProfileDisplayNameEditor(
          state: state,
          onChanged: ref
              .read(profileDisplayNameEditorControllerProvider.notifier)
              .updateValue,
          onClear: ref
              .read(profileDisplayNameEditorControllerProvider.notifier)
              .clear,
          onSubmitted: state.canSave ? () => _save(context, ref) : () {},
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = await ref
        .read(profileDisplayNameEditorControllerProvider.notifier)
        .save();
    if (!context.mounted || !saved) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('닉네임을 변경했어요.')));
    context.pop();
  }
}

class _ProfileDisplayNameEditor extends StatelessWidget {
  const _ProfileDisplayNameEditor({
    required this.state,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
  });

  final ProfileDisplayNameEditorState state;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const Text('어떻게 불러주면 될까?', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 8),
        Text(
          '상대방에게 보이는 생일과 둘만의 공간에서 사용할 이름이야',
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        ProfileDisplayNameField(
          value: state.value,
          isValid: state.isValid,
          autofocus: true,
          onChanged: onChanged,
          onClear: onClear,
          onSubmitted: onSubmitted,
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
          const Text('닉네임을 불러오지 못했어요.', style: AppTextStyles.homeBodyMedium),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
