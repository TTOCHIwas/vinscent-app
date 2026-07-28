import '../data/account_deletion_repository.dart';
import 'account_local_data_cleanup.dart';

typedef AccountSessionFinalizer = Future<void> Function();

abstract interface class AccountDeletionExecutor {
  Future<AccountDeletionOutcome> execute({required String userId});
}

class AccountDeletionOutcome {
  const AccountDeletionOutcome({
    required this.receipt,
    required this.localCleanup,
    this.sessionFinalizationError,
    this.sessionFinalizationStackTrace,
  });

  final AccountDeletionReceipt receipt;
  final AccountLocalDataCleanupResult localCleanup;
  final Object? sessionFinalizationError;
  final StackTrace? sessionFinalizationStackTrace;
}

class AccountDeletionService implements AccountDeletionExecutor {
  const AccountDeletionService({
    required AccountDeletionRepository repository,
    required AccountLocalDataCleanup localDataCleanup,
    required AccountSessionFinalizer clearSession,
  }) : _repository = repository,
       _localDataCleanup = localDataCleanup,
       _clearSession = clearSession;

  final AccountDeletionRepository _repository;
  final AccountLocalDataCleanup _localDataCleanup;
  final AccountSessionFinalizer _clearSession;

  @override
  Future<AccountDeletionOutcome> execute({required String userId}) async {
    final receipt = await _repository.deleteAccount();
    final localCleanup = await _localDataCleanup.execute(userId);
    Object? sessionFinalizationError;
    StackTrace? sessionFinalizationStackTrace;

    try {
      await _clearSession();
    } catch (error, stackTrace) {
      sessionFinalizationError = error;
      sessionFinalizationStackTrace = stackTrace;
    }

    return AccountDeletionOutcome(
      receipt: receipt,
      localCleanup: localCleanup,
      sessionFinalizationError: sessionFinalizationError,
      sessionFinalizationStackTrace: sessionFinalizationStackTrace,
    );
  }
}
