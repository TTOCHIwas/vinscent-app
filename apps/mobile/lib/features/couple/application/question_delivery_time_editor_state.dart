import '../data/question_delivery_time.dart';

class QuestionDeliveryTimeEditorState {
  const QuestionDeliveryTimeEditorState({
    required this.effectiveTime,
    required this.selectedTime,
    this.pendingTime,
    this.pendingEffectiveDate,
    this.isSaving = false,
    this.errorMessage,
  });

  final QuestionDeliveryTime effectiveTime;
  final QuestionDeliveryTime selectedTime;
  final QuestionDeliveryTime? pendingTime;
  final DateTime? pendingEffectiveDate;
  final bool isSaving;
  final String? errorMessage;

  QuestionDeliveryTime get savedTime => pendingTime ?? effectiveTime;

  bool get hasChanged => selectedTime != savedTime;

  bool get canSave => hasChanged && !isSaving;

  QuestionDeliveryTimeEditorState copyWith({
    QuestionDeliveryTime? effectiveTime,
    QuestionDeliveryTime? selectedTime,
    QuestionDeliveryTime? pendingTime,
    DateTime? pendingEffectiveDate,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return QuestionDeliveryTimeEditorState(
      effectiveTime: effectiveTime ?? this.effectiveTime,
      selectedTime: selectedTime ?? this.selectedTime,
      pendingTime: pendingTime ?? this.pendingTime,
      pendingEffectiveDate: pendingEffectiveDate ?? this.pendingEffectiveDate,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
