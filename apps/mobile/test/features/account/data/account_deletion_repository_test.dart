import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinscent/features/account/data/account_deletion_repository.dart';

void main() {
  test('parses a successful account deletion receipt', () async {
    final repository = SupabaseAccountDeletionRepository(
      isConfigured: true,
      invoke: (_) async => {'status': 'deleted', 'deletedCoupleCount': 2},
    );

    await expectLater(
      repository.deleteAccount(),
      completion(const AccountDeletionReceipt(deletedCoupleCount: 2)),
    );
  });

  test('passes a fresh Apple authorization code to the function', () async {
    String? receivedCode;
    final repository = SupabaseAccountDeletionRepository(
      isConfigured: true,
      invoke: (authorizationCode) async {
        receivedCode = authorizationCode;
        return {'status': 'deleted', 'deletedCoupleCount': 1};
      },
    );

    await repository.deleteAccount(
      appleAuthorizationCode: 'authorization-code',
    );

    expect(receivedCode, 'authorization-code');
  });

  test('rejects an invalid account deletion response', () async {
    final repository = SupabaseAccountDeletionRepository(
      isConfigured: true,
      invoke: (_) async => {'status': 'deleted', 'deletedCoupleCount': '2'},
    );

    await expectLater(
      repository.deleteAccount(),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.reason,
          'reason',
          AccountDeletionFailureReason.invalidResponse,
        ),
      ),
    );
  });

  test('maps an unauthorized function response to session expired', () async {
    final repository = SupabaseAccountDeletionRepository(
      isConfigured: true,
      invoke: (_) async => throw const FunctionException(status: 401),
    );

    await expectLater(
      repository.deleteAccount(),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.reason,
          'reason',
          AccountDeletionFailureReason.sessionExpired,
        ),
      ),
    );
  });

  test('maps an Apple reauthentication requirement', () async {
    final repository = SupabaseAccountDeletionRepository(
      isConfigured: true,
      invoke: (_) async => throw const FunctionException(status: 409),
    );

    await expectLater(
      repository.deleteAccount(),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.reason,
          'reason',
          AccountDeletionFailureReason.reauthenticationRequired,
        ),
      ),
    );
  });

  test('maps a request timeout', () async {
    final pending = Completer<Object?>();
    final repository = SupabaseAccountDeletionRepository(
      isConfigured: true,
      invoke: (_) => pending.future,
      timeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      repository.deleteAccount(),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.reason,
          'reason',
          AccountDeletionFailureReason.requestTimeout,
        ),
      ),
    );
  });

  test('rejects deletion when Supabase is not configured', () async {
    final repository = SupabaseAccountDeletionRepository(
      isConfigured: false,
      invoke: (_) async => const {},
    );

    await expectLater(
      repository.deleteAccount(),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.reason,
          'reason',
          AccountDeletionFailureReason.configMissing,
        ),
      ),
    );
  });
}
