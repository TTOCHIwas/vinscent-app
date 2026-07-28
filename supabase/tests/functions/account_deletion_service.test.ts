import assert from 'node:assert/strict';
import test from 'node:test';

import {
  type AccountDeletionGateway,
  AccountDeletionService,
} from '../../functions/delete-account/account_deletion_service.ts';

test('deletes shared data before deleting the authentication account', async () => {
  const calls: string[] = [];
  const gateway: AccountDeletionGateway = {
    async deleteSharedData(userId) {
      calls.push(`shared:${userId}`);
      return 2;
    },
    async deleteAuthUser(userId) {
      calls.push(`auth:${userId}`);
    },
  };

  const result = await new AccountDeletionService(gateway).deleteAccount(
    ' user-1 ',
  );

  assert.deepEqual(calls, ['shared:user-1', 'auth:user-1']);
  assert.deepEqual(result, { deletedCoupleCount: 2 });
});

test('does not delete authentication when shared data deletion fails', async () => {
  let authDeletionCalled = false;
  const gateway: AccountDeletionGateway = {
    async deleteSharedData() {
      throw new Error('shared_data_deletion_failed');
    },
    async deleteAuthUser() {
      authDeletionCalled = true;
    },
  };

  await assert.rejects(
    () => new AccountDeletionService(gateway).deleteAccount('user-1'),
    /shared_data_deletion_failed/,
  );
  assert.equal(authDeletionCalled, false);
});

test('propagates authentication deletion failures for a safe retry', async () => {
  const gateway: AccountDeletionGateway = {
    async deleteSharedData() {
      return 0;
    },
    async deleteAuthUser() {
      throw new Error('auth_user_deletion_failed');
    },
  };

  await assert.rejects(
    () => new AccountDeletionService(gateway).deleteAccount('user-1'),
    /auth_user_deletion_failed/,
  );
});

test('rejects an empty account user id', async () => {
  const gateway: AccountDeletionGateway = {
    async deleteSharedData() {
      return 0;
    },
    async deleteAuthUser() {},
  };

  await assert.rejects(
    () => new AccountDeletionService(gateway).deleteAccount('  '),
    /account_user_required/,
  );
});
