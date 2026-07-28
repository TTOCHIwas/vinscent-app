import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/account/application/account_deletion_service.dart';
import 'package:vinscent/features/account/application/account_local_data_cleanup.dart';
import 'package:vinscent/features/account/data/account_deletion_repository.dart';

void main() {
  test('deletes remote account before local data and session', () async {
    final events = <String>[];
    final service = AccountDeletionService(
      repository: _FakeAccountDeletionRepository(() async {
        events.add('remote');
        return const AccountDeletionReceipt(deletedCoupleCount: 1);
      }),
      localDataCleanup: _localCleanup(events: events),
      clearSession: () async {
        events.add('session');
      },
    );

    final outcome = await service.execute(userId: 'user-a');

    expect(outcome.receipt.deletedCoupleCount, 1);
    expect(outcome.localCleanup.isComplete, isTrue);
    expect(outcome.sessionFinalizationError, isNull);
    expect(events, [
      'remote',
      'proactive:user-a',
      'calendar:user-a',
      'feedback:user-a',
      'recording',
      'widgets',
      'session',
    ]);
  });

  test('preserves local state when remote deletion fails', () async {
    final events = <String>[];
    final service = AccountDeletionService(
      repository: _FakeAccountDeletionRepository(() async {
        events.add('remote');
        throw const AccountDeletionException(
          AccountDeletionFailureReason.requestFailed,
        );
      }),
      localDataCleanup: _localCleanup(events: events),
      clearSession: () async {
        events.add('session');
      },
    );

    await expectLater(
      service.execute(userId: 'user-a'),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.reason,
          'reason',
          AccountDeletionFailureReason.requestFailed,
        ),
      ),
    );
    expect(events, ['remote']);
  });

  test('local cleanup failures do not block session finalization', () async {
    final events = <String>[];
    final service = AccountDeletionService(
      repository: _FakeAccountDeletionRepository(() async {
        events.add('remote');
        return const AccountDeletionReceipt(deletedCoupleCount: 0);
      }),
      localDataCleanup: _localCleanup(events: events, failFeedback: true),
      clearSession: () async {
        events.add('session');
      },
    );

    final outcome = await service.execute(userId: 'user-a');

    expect(outcome.localCleanup.isComplete, isFalse);
    expect(
      outcome.localCleanup.failures.single.operation,
      AccountLocalDataCleanupOperation.homeFeedbackImpression,
    );
    expect(events.last, 'session');
  });

  test(
    'session finalization failure does not reverse remote deletion',
    () async {
      final service = AccountDeletionService(
        repository: _FakeAccountDeletionRepository(
          () async => const AccountDeletionReceipt(deletedCoupleCount: 1),
        ),
        localDataCleanup: _localCleanup(events: <String>[]),
        clearSession: () async {
          throw StateError('session failed');
        },
      );

      final outcome = await service.execute(userId: 'user-a');

      expect(outcome.receipt.deletedCoupleCount, 1);
      expect(outcome.sessionFinalizationError, isA<StateError>());
    },
  );
}

AccountLocalDataCleanup _localCleanup({
  required List<String> events,
  bool failFeedback = false,
}) {
  return AccountLocalDataCleanup(
    clearProactiveSuggestion: (userId) async {
      events.add('proactive:$userId');
    },
    clearCalendarPreviewPreference: (userId) async {
      events.add('calendar:$userId');
    },
    clearHomeFeedbackImpression: (userId) async {
      events.add('feedback:$userId');
      if (failFeedback) {
        throw StateError('feedback failed');
      }
    },
    clearPendingRecordingDrafts: () async {
      events.add('recording');
    },
    clearHomeWidgets: () async {
      events.add('widgets');
    },
  );
}

class _FakeAccountDeletionRepository implements AccountDeletionRepository {
  const _FakeAccountDeletionRepository(this.onDelete);

  final Future<AccountDeletionReceipt> Function() onDelete;

  @override
  Future<AccountDeletionReceipt> deleteAccount() => onDelete();
}
