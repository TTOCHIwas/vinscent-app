import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_controller.dart';
import 'profile_display_name_editor_state.dart';
import 'profile_display_name_policy.dart';

final profileDisplayNameEditorControllerProvider =
    AsyncNotifierProvider.autoDispose<
      ProfileDisplayNameEditorController,
      ProfileDisplayNameEditorState
    >(ProfileDisplayNameEditorController.new, retry: (_, _) => null);

class ProfileDisplayNameEditorController
    extends AsyncNotifier<ProfileDisplayNameEditorState> {
  @override
  Future<ProfileDisplayNameEditorState> build() async {
    final profile = await ref.read(profileControllerProvider.future);
    if (profile == null) {
      throw StateError('A profile is required to edit the display name.');
    }

    final displayName = normalizeProfileDisplayName(profile.displayName);
    return ProfileDisplayNameEditorState(
      originalValue: displayName,
      value: displayName,
    );
  }

  void updateValue(String value) {
    final current = state.asData?.value;
    if (current == null || current.isSaving) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(value: value, clearErrorMessage: true),
    );
  }

  void clear() => updateValue('');

  Future<bool> save() async {
    final current = state.asData?.value;
    if (current == null || !current.canSave) {
      return false;
    }

    state = AsyncValue.data(
      current.copyWith(isSaving: true, clearErrorMessage: true),
    );
    try {
      final profile = await ref
          .read(profileControllerProvider.notifier)
          .updateDisplayName(current.normalizedValue);
      if (ref.mounted) {
        final displayName = normalizeProfileDisplayName(profile.displayName);
        state = AsyncValue.data(
          current.copyWith(
            originalValue: displayName,
            value: displayName,
            isSaving: false,
            clearErrorMessage: true,
          ),
        );
      }
      return true;
    } catch (_) {
      if (ref.mounted) {
        state = AsyncValue.data(
          current.copyWith(
            isSaving: false,
            errorMessage: '닉네임을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
          ),
        );
      }
      return false;
    }
  }
}
