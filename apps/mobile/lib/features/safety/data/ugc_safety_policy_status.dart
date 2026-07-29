class UgcSafetyPolicyStatus {
  const UgcSafetyPolicyStatus({
    required this.policyVersion,
    required this.isAccepted,
    required this.acceptedAt,
  });

  factory UgcSafetyPolicyStatus.fromJson(Map<String, dynamic> json) {
    final policyVersion = json['policy_version'];
    final isAccepted = json['is_accepted'];
    final acceptedAtValue = json['accepted_at'];

    if (policyVersion is! String ||
        policyVersion.trim().isEmpty ||
        isAccepted is! bool ||
        (acceptedAtValue != null && acceptedAtValue is! String)) {
      throw const FormatException('Invalid UGC safety policy status');
    }

    final acceptedAt = acceptedAtValue == null
        ? null
        : DateTime.tryParse(acceptedAtValue)?.toUtc();
    if ((acceptedAtValue != null && acceptedAt == null) ||
        (isAccepted && acceptedAt == null) ||
        (!isAccepted && acceptedAt != null)) {
      throw const FormatException('Invalid UGC safety policy status');
    }

    return UgcSafetyPolicyStatus(
      policyVersion: policyVersion,
      isAccepted: isAccepted,
      acceptedAt: acceptedAt,
    );
  }

  final String policyVersion;
  final bool isAccepted;
  final DateTime? acceptedAt;

  @override
  bool operator ==(Object other) {
    return other is UgcSafetyPolicyStatus &&
        other.policyVersion == policyVersion &&
        other.isAccepted == isAccepted &&
        other.acceptedAt == acceptedAt;
  }

  @override
  int get hashCode => Object.hash(policyVersion, isAccepted, acceptedAt);
}
