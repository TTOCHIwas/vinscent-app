import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinscent/features/safety/data/user_block_failure.dart';
import 'package:vinscent/features/safety/data/user_block_repository.dart';

void main() {
  test('maps blocked users and reconnectable archives from RPC rows', () async {
    final repository = SupabaseUserBlockRepository(
      isConfigured: true,
      invoke: (function, params) async {
        return switch (function) {
          'list_blocked_users' => [
            {
              'user_id': 'blocked-user-id',
              'display_name': '상대방',
              'blocked_at': '2026-07-29T01:00:00.000Z',
            },
          ],
          'list_reconnectable_couple_archives' => [
            {
              'couple_id': 'couple-id',
              'partner_user_id': 'former-partner-id',
              'partner_display_name': '이전 상대방',
              'archive_expires_at': '2026-08-28T01:00:00.000Z',
            },
          ],
          _ => throw StateError('Unexpected RPC: $function'),
        };
      },
    );

    final blockedUsers = await repository.fetchBlockedUsers();
    final archives = await repository.fetchReconnectableArchives();

    expect(blockedUsers.single.userId, 'blocked-user-id');
    expect(blockedUsers.single.displayName, '상대방');
    expect(blockedUsers.single.blockedAt.toUtc(), DateTime.utc(2026, 7, 29, 1));
    expect(archives.single.coupleId, 'couple-id');
    expect(archives.single.partnerUserId, 'former-partner-id');
    expect(archives.single.partnerDisplayName, '이전 상대방');
    expect(
      archives.single.archiveExpiresAt.toUtc(),
      DateTime.utc(2026, 8, 28, 1),
    );
  });

  test(
    'uses the explicit block, unblock, and reconnect RPC contracts',
    () async {
      final calls = <({String function, Map<String, Object?>? params})>[];
      final repository = SupabaseUserBlockRepository(
        isConfigured: true,
        invoke: (function, params) async {
          calls.add((function: function, params: params));
          return function == 'unblock_user' ? true : null;
        },
      );

      await repository.blockCurrentPartner();
      final wasUnblocked = await repository.unblockUser('blocked-user-id');
      await repository.createReconnectInvite('couple-id');

      expect(wasUnblocked, isTrue);
      expect(calls, [
        (function: 'block_current_partner', params: null),
        (
          function: 'unblock_user',
          params: {'target_user_id': 'blocked-user-id'},
        ),
        (
          function: 'create_couple_archive_reconnect_invite',
          params: {'target_couple_id': 'couple-id'},
        ),
      ]);
    },
  );

  test(
    'maps a blocked pair response without leaking Postgrest details',
    () async {
      final repository = SupabaseUserBlockRepository(
        isConfigured: true,
        invoke: (function, params) async {
          throw const PostgrestException(message: 'user_blocked');
        },
      );

      await expectLater(
        repository.createReconnectInvite('couple-id'),
        throwsA(
          isA<UserBlockException>().having(
            (error) => error.reason,
            'reason',
            UserBlockFailureReason.userBlocked,
          ),
        ),
      );
    },
  );

  test('rejects actions when Supabase is not configured', () async {
    var invoked = false;
    final repository = SupabaseUserBlockRepository(
      isConfigured: false,
      invoke: (function, params) async {
        invoked = true;
        return null;
      },
    );

    await expectLater(
      repository.blockCurrentPartner(),
      throwsA(
        isA<UserBlockException>().having(
          (error) => error.reason,
          'reason',
          UserBlockFailureReason.configMissing,
        ),
      ),
    );
    expect(invoked, isFalse);
  });

  test('maps a user block request timeout', () async {
    final pending = Completer<Object?>();
    final repository = SupabaseUserBlockRepository(
      isConfigured: true,
      timeout: const Duration(milliseconds: 1),
      invoke: (function, params) => pending.future,
    );

    await expectLater(
      repository.fetchBlockedUsers(),
      throwsA(
        isA<UserBlockException>().having(
          (error) => error.reason,
          'reason',
          UserBlockFailureReason.requestTimeout,
        ),
      ),
    );
  });
}
