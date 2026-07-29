import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinscent/features/safety/data/ugc_safety_policy_failure.dart';
import 'package:vinscent/features/safety/data/ugc_safety_policy_repository.dart';

void main() {
  test('fetches the current UGC safety policy status', () async {
    String? receivedFunctionName;
    Map<String, Object?>? receivedParams;
    final repository = SupabaseUgcSafetyPolicyRepository(
      isConfigured: true,
      invoke: (functionName, params) async {
        receivedFunctionName = functionName;
        receivedParams = params;
        return [
          {
            'policy_version': 'ugc-safety-v1',
            'is_accepted': false,
            'accepted_at': null,
          },
        ];
      },
    );

    final status = await repository.fetchStatus();

    expect(receivedFunctionName, 'get_my_ugc_safety_policy_status');
    expect(receivedParams, isNull);
    expect(status.policyVersion, 'ugc-safety-v1');
    expect(status.isAccepted, isFalse);
    expect(status.acceptedAt, isNull);
  });

  test('accepts the exact version returned by the server', () async {
    String? receivedFunctionName;
    Map<String, Object?>? receivedParams;
    final repository = SupabaseUgcSafetyPolicyRepository(
      isConfigured: true,
      invoke: (functionName, params) async {
        receivedFunctionName = functionName;
        receivedParams = params;
        return {
          'policy_version': 'ugc-safety-v1',
          'is_accepted': true,
          'accepted_at': '2026-07-29T01:02:03Z',
        };
      },
    );

    final status = await repository.accept(policyVersion: 'ugc-safety-v1');

    expect(receivedFunctionName, 'accept_current_ugc_safety_policy');
    expect(receivedParams, {'requested_policy_version': 'ugc-safety-v1'});
    expect(status.isAccepted, isTrue);
    expect(status.acceptedAt, DateTime.utc(2026, 7, 29, 1, 2, 3));
  });

  test('rejects requests when Supabase is not configured', () async {
    var invoked = false;
    final repository = SupabaseUgcSafetyPolicyRepository(
      isConfigured: false,
      invoke: (functionName, params) async {
        invoked = true;
        return null;
      },
    );

    await expectLater(
      repository.fetchStatus(),
      throwsA(
        isA<UgcSafetyPolicyException>().having(
          (error) => error.reason,
          'reason',
          UgcSafetyPolicyFailureReason.configMissing,
        ),
      ),
    );
    expect(invoked, isFalse);
  });

  test('maps an expired session response', () async {
    final repository = SupabaseUgcSafetyPolicyRepository(
      isConfigured: true,
      invoke: (functionName, params) async {
        throw const PostgrestException(message: 'auth_required');
      },
    );

    await expectLater(
      repository.fetchStatus(),
      throwsA(
        isA<UgcSafetyPolicyException>().having(
          (error) => error.reason,
          'reason',
          UgcSafetyPolicyFailureReason.authRequired,
        ),
      ),
    );
  });

  test('maps an outdated policy version response', () async {
    final repository = SupabaseUgcSafetyPolicyRepository(
      isConfigured: true,
      invoke: (functionName, params) async {
        throw const PostgrestException(
          message: 'ugc_safety_policy_version_outdated',
        );
      },
    );

    await expectLater(
      repository.accept(policyVersion: 'ugc-safety-old'),
      throwsA(
        isA<UgcSafetyPolicyException>().having(
          (error) => error.reason,
          'reason',
          UgcSafetyPolicyFailureReason.versionOutdated,
        ),
      ),
    );
  });

  test('maps a request timeout', () async {
    final pending = Completer<Object?>();
    final repository = SupabaseUgcSafetyPolicyRepository(
      isConfigured: true,
      timeout: const Duration(milliseconds: 1),
      invoke: (functionName, params) => pending.future,
    );

    await expectLater(
      repository.fetchStatus(),
      throwsA(
        isA<UgcSafetyPolicyException>().having(
          (error) => error.reason,
          'reason',
          UgcSafetyPolicyFailureReason.requestTimeout,
        ),
      ),
    );
  });

  test('rejects an inconsistent accepted response', () async {
    final repository = SupabaseUgcSafetyPolicyRepository(
      isConfigured: true,
      invoke: (functionName, params) async {
        return {
          'policy_version': 'ugc-safety-v1',
          'is_accepted': true,
          'accepted_at': null,
        };
      },
    );

    await expectLater(
      repository.fetchStatus(),
      throwsA(
        isA<UgcSafetyPolicyException>().having(
          (error) => error.reason,
          'reason',
          UgcSafetyPolicyFailureReason.invalidResponse,
        ),
      ),
    );
  });
}
