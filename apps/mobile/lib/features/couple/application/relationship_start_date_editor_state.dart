class RelationshipStartDateEditorState {
  const RelationshipStartDateEditorState({
    required this.originalDate,
    required this.selectedDate,
    required this.latestAllowedDate,
    this.isSaving = false,
    this.errorMessage,
  });

  final DateTime originalDate;
  final DateTime selectedDate;
  final DateTime latestAllowedDate;
  final bool isSaving;
  final String? errorMessage;

  bool get hasChanged => selectedDate != originalDate;

  bool get canSave => hasChanged && !isSaving;

  RelationshipStartDateEditorState copyWith({
    DateTime? originalDate,
    DateTime? selectedDate,
    DateTime? latestAllowedDate,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return RelationshipStartDateEditorState(
      originalDate: originalDate ?? this.originalDate,
      selectedDate: selectedDate ?? this.selectedDate,
      latestAllowedDate: latestAllowedDate ?? this.latestAllowedDate,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
