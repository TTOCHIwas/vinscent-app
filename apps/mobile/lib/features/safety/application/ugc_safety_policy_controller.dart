import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../data/ugc_safety_policy_failure.dart';
import '../data/ugc_safety_policy_repository.dart';
import '../data/ugc_safety_policy_status.dart';

final ugcSafetyPolicyControllerProvider =
    AsyncNotifierProvider<UgcSafetyPolicyController, UgcSafetyPolicyStatus?>(
      UgcSafetyPolicyController.new,
    );

class UgcSafetyPolicyController extends AsyncNotifier<UgcSafetyPolicyStatus?> {
  Future<UgcSafetyPolicyStatus>? _pendingAcceptance;

  @override
  Future<UgcSafetyPolicyStatus?> build() async {
    final authStatus = ref.watch(authControllerProvider);
    if (authStatus != AuthStatus.authenticated) {
      return null;
    }

    return ref.watch(ugcSafetyPolicyRepositoryProvider).fetchStatus();
  }

  Future<UgcSafetyPolicyStatus> acceptCurrentPolicy() {
    return _pendingAcceptance ??= _acceptCurrentPolicy().whenComplete(() {
      _pendingAcceptance = null;
    });
  }

  Future<UgcSafetyPolicyStatus> _acceptCurrentPolicy() async {
    final currentStatus = state.value;
    if (currentStatus == null) {
      throw const UgcSafetyPolicyException(
        UgcSafetyPolicyFailureReason.invalidResponse,
      );
    }

    try {
      final acceptedStatus = await ref
          .read(ugcSafetyPolicyRepositoryProvider)
          .accept(policyVersion: currentStatus.policyVersion);
      state = AsyncData(acceptedStatus);
      return acceptedStatus;
    } on UgcSafetyPolicyException catch (error) {
      if (error.reason == UgcSafetyPolicyFailureReason.versionOutdated) {
        ref.invalidateSelf();
      }
      rethrow;
    }
  }
}
