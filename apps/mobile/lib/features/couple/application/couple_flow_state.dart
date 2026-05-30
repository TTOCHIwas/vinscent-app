enum CoupleFlowOperation { idle, creating, joining, cancelling, savingDate }

class CoupleFlowState {
  const CoupleFlowState({
    this.inviteCode = '',
    this.relationshipStartDate,
    this.operation = CoupleFlowOperation.idle,
    this.errorMessage,
  });

  final String inviteCode;
  final DateTime? relationshipStartDate;
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

  CoupleFlowState copyWith({
    String? inviteCode,
    DateTime? relationshipStartDate,
    CoupleFlowOperation? operation,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return CoupleFlowState(
      inviteCode: inviteCode ?? this.inviteCode,
      relationshipStartDate:
          relationshipStartDate ?? this.relationshipStartDate,
      operation: operation ?? this.operation,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
