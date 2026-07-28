import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_deletion_repository.dart';
import 'account_deletion_providers.dart';

final accountDeletionControllerProvider =
    NotifierProvider<AccountDeletionController, AccountDeletionState>(
      AccountDeletionController.new,
    );

enum AccountDeletionPhase { idle, deleting, completed, failed }

class AccountDeletionState {
  const AccountDeletionState({
    this.phase = AccountDeletionPhase.idle,
    this.failureReason,
  });

  final AccountDeletionPhase phase;
  final AccountDeletionFailureReason? failureReason;

  bool get isDeleting => phase == AccountDeletionPhase.deleting;
}

class AccountDeletionController extends Notifier<AccountDeletionState> {
  @override
  AccountDeletionState build() => const AccountDeletionState();

  Future<bool> deleteAccount() async {
    if (state.isDeleting) {
      return false;
    }

    final userId = ref.read(accountCurrentUserIdProvider);
    if (userId == null) {
      state = const AccountDeletionState(
        phase: AccountDeletionPhase.failed,
        failureReason: AccountDeletionFailureReason.sessionExpired,
      );
      return false;
    }

    state = const AccountDeletionState(phase: AccountDeletionPhase.deleting);
    try {
      final appleAuthorizationCode = await ref
          .read(accountDeletionAuthorizerProvider)
          .authorize();
      final outcome = await ref
          .read(accountDeletionExecutorProvider)
          .execute(
            userId: userId,
            appleAuthorizationCode: appleAuthorizationCode,
          );
      if (kDebugMode &&
          (!outcome.localCleanup.isComplete ||
              outcome.sessionFinalizationError != null)) {
        debugPrint(
          '[account] deletion completed with local cleanup warnings: '
          '${outcome.localCleanup.failures.length} cleanup failure(s), '
          'session error=${outcome.sessionFinalizationError}',
        );
      }
      state = const AccountDeletionState(phase: AccountDeletionPhase.completed);
      return true;
    } on AccountDeletionException catch (error) {
      state = AccountDeletionState(
        phase: AccountDeletionPhase.failed,
        failureReason: error.reason,
      );
      return false;
    } catch (_) {
      state = const AccountDeletionState(
        phase: AccountDeletionPhase.failed,
        failureReason: AccountDeletionFailureReason.unknown,
      );
      return false;
    }
  }
}
