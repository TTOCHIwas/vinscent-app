import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/account/application/account_deletion_authorizer.dart';
import 'package:vinscent/features/account/application/account_deletion_controller.dart';
import 'package:vinscent/features/account/application/account_deletion_providers.dart';
import 'package:vinscent/features/account/application/account_deletion_service.dart';
import 'package:vinscent/features/account/application/account_local_data_cleanup.dart';
import 'package:vinscent/features/account/data/account_deletion_repository.dart';

void main() {
  test('completes deletion for the authenticated user', () async {
    final executor = _FakeAccountDeletionExecutor();
    final container = _container(userId: 'user-a', executor: executor);
    addTearDown(container.dispose);

    final succeeded = await container
        .read(accountDeletionControllerProvider.notifier)
        .deleteAccount();

    expect(succeeded, isTrue);
    expect(executor.userIds, ['user-a']);
    expect(
      container.read(accountDeletionControllerProvider).phase,
      AccountDeletionPhase.completed,
    );
  });

  test('rejects deletion when the authenticated user is missing', () async {
    final executor = _FakeAccountDeletionExecutor();
    final container = _container(userId: null, executor: executor);
    addTearDown(container.dispose);

    final succeeded = await container
        .read(accountDeletionControllerProvider.notifier)
        .deleteAccount();

    final state = container.read(accountDeletionControllerProvider);
    expect(succeeded, isFalse);
    expect(executor.userIds, isEmpty);
    expect(state.phase, AccountDeletionPhase.failed);
    expect(state.failureReason, AccountDeletionFailureReason.sessionExpired);
  });

  test('prevents duplicate deletion requests while one is running', () async {
    final barrier = Completer<AccountDeletionOutcome>();
    final executor = _FakeAccountDeletionExecutor(barrier: barrier);
    final container = _container(userId: 'user-a', executor: executor);
    addTearDown(container.dispose);
    final controller = container.read(
      accountDeletionControllerProvider.notifier,
    );

    final first = controller.deleteAccount();
    final second = await controller.deleteAccount();

    expect(second, isFalse);
    expect(executor.userIds, ['user-a']);
    barrier.complete(_outcome());
    expect(await first, isTrue);
  });

  test('exposes a typed remote deletion failure', () async {
    final executor = _FakeAccountDeletionExecutor(
      error: const AccountDeletionException(
        AccountDeletionFailureReason.requestTimeout,
      ),
    );
    final container = _container(userId: 'user-a', executor: executor);
    addTearDown(container.dispose);

    final succeeded = await container
        .read(accountDeletionControllerProvider.notifier)
        .deleteAccount();

    final state = container.read(accountDeletionControllerProvider);
    expect(succeeded, isFalse);
    expect(state.phase, AccountDeletionPhase.failed);
    expect(state.failureReason, AccountDeletionFailureReason.requestTimeout);
  });

  test('passes deletion reauthentication to the executor', () async {
    final executor = _FakeAccountDeletionExecutor();
    final container = _container(
      userId: 'user-a',
      executor: executor,
      authorizer: _FakeAccountDeletionAuthorizer(
        authorizationCode: 'authorization-code',
      ),
    );
    addTearDown(container.dispose);

    final succeeded = await container
        .read(accountDeletionControllerProvider.notifier)
        .deleteAccount();

    expect(succeeded, isTrue);
    expect(executor.authorizationCodes, ['authorization-code']);
  });

  test('does not execute deletion when reauthentication is cancelled', () async {
    final executor = _FakeAccountDeletionExecutor();
    final container = _container(
      userId: 'user-a',
      executor: executor,
      authorizer: _FakeAccountDeletionAuthorizer(
        error: const AccountDeletionException(
          AccountDeletionFailureReason.reauthenticationCancelled,
        ),
      ),
    );
    addTearDown(container.dispose);

    final succeeded = await container
        .read(accountDeletionControllerProvider.notifier)
        .deleteAccount();

    expect(succeeded, isFalse);
    expect(executor.userIds, isEmpty);
    expect(
      container.read(accountDeletionControllerProvider).failureReason,
      AccountDeletionFailureReason.reauthenticationCancelled,
    );
  });
}

ProviderContainer _container({
  required String? userId,
  required AccountDeletionExecutor executor,
  AccountDeletionAuthorizationProvider? authorizer,
}) {
  return ProviderContainer(
    overrides: [
      accountCurrentUserIdProvider.overrideWithValue(userId),
      accountDeletionAuthorizerProvider.overrideWithValue(
        authorizer ?? _FakeAccountDeletionAuthorizer(),
      ),
      accountDeletionExecutorProvider.overrideWithValue(executor),
    ],
  );
}

AccountDeletionOutcome _outcome() {
  return AccountDeletionOutcome(
    receipt: const AccountDeletionReceipt(deletedCoupleCount: 1),
    localCleanup: AccountLocalDataCleanupResult(failures: const []),
  );
}

class _FakeAccountDeletionExecutor implements AccountDeletionExecutor {
  _FakeAccountDeletionExecutor({this.barrier, this.error});

  final Completer<AccountDeletionOutcome>? barrier;
  final Object? error;
  final userIds = <String>[];
  final authorizationCodes = <String?>[];

  @override
  Future<AccountDeletionOutcome> execute({
    required String userId,
    String? appleAuthorizationCode,
  }) async {
    userIds.add(userId);
    authorizationCodes.add(appleAuthorizationCode);
    if (error case final error?) {
      throw error;
    }
    return barrier?.future ?? _outcome();
  }
}

class _FakeAccountDeletionAuthorizer
    implements AccountDeletionAuthorizationProvider {
  const _FakeAccountDeletionAuthorizer({
    this.authorizationCode,
    this.error,
  });

  final String? authorizationCode;
  final Object? error;

  @override
  Future<String?> authorize() async {
    if (error case final error?) {
      throw error;
    }
    return authorizationCode;
  }
}
