import 'profile_display_name_policy.dart';

class ProfileDisplayNameEditorState {
  const ProfileDisplayNameEditorState({
    required this.originalValue,
    required this.value,
    this.isSaving = false,
    this.errorMessage,
  });

  final String originalValue;
  final String value;
  final bool isSaving;
  final String? errorMessage;

  String get normalizedValue => normalizeProfileDisplayName(value);

  bool get isValid => isValidProfileDisplayName(value);

  bool get hasChanged => normalizedValue != originalValue;

  bool get canSave => isValid && hasChanged && !isSaving;

  ProfileDisplayNameEditorState copyWith({
    String? originalValue,
    String? value,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ProfileDisplayNameEditorState(
      originalValue: originalValue ?? this.originalValue,
      value: value ?? this.value,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
