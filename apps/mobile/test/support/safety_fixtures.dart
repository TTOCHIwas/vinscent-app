import 'package:vinscent/features/safety/data/ugc_safety_policy_status.dart';

UgcSafetyPolicyStatus acceptedUgcSafetyPolicyStatus() {
  return UgcSafetyPolicyStatus(
    policyVersion: 'ugc-safety-v1',
    isAccepted: true,
    acceptedAt: DateTime.utc(2026, 7, 29),
  );
}

UgcSafetyPolicyStatus pendingUgcSafetyPolicyStatus() {
  return const UgcSafetyPolicyStatus(
    policyVersion: 'ugc-safety-v1',
    isAccepted: false,
    acceptedAt: null,
  );
}
