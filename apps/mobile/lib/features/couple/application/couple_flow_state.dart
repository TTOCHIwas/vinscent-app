import '../data/question_delivery_time.dart';

enum CoupleFlowOperation {
  idle,
  creating,
  joining,
  cancelling,
  cancellingSetup,
  savingDate,
  savingQuestionTime,
}

class CoupleFlowState {
  const CoupleFlowState({
    this.inviteCode = '',
    this.relationshipStartDate,
    this.questionDeliveryTime = const QuestionDeliveryTime(hour: 9, minute: 0),
    this.operation = CoupleFlowOperation.idle,
    this.errorMessage,
  });

  final String inviteCode;
  final DateTime? relationshipStartDate;
  final QuestionDeliveryTime questionDeliveryTime;
  final CoupleFlowOperation operation;
  final String? errorMessage;

  String get normalizedInviteCode => inviteCode.trim().toUpperCase();

  bool get isInviteCodeValid {
    return RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(normalizedInviteCode);
  }

  bool get hasSelectedDate => relationshipStartDate != null;

  bool get isSubmitting => operation != CoupleFlowOperation.idle;

  bool get canJoin => isInviteCodeValid && !isSubmitting;

  bool get canSaveDate => hasSelectedDate && !isSubmitting;

  bool get canSaveQuestionTime => !isSubmitting;

  CoupleFlowState copyWith({
    String? inviteCode,
    DateTime? relationshipStartDate,
    QuestionDeliveryTime? questionDeliveryTime,
    CoupleFlowOperation? operation,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return CoupleFlowState(
      inviteCode: inviteCode ?? this.inviteCode,
      relationshipStartDate:
          relationshipStartDate ?? this.relationshipStartDate,
      questionDeliveryTime: questionDeliveryTime ?? this.questionDeliveryTime,
      operation: operation ?? this.operation,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
