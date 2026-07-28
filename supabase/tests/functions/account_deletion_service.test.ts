import assert from 'node:assert/strict';
import test from 'node:test';

import {
  type AccountDeletionGateway,
  type AppleAuthorizationRevoker,
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

test('revokes Apple authorization before deleting any account data', async () => {
  const calls: string[] = [];
  const gateway: AccountDeletionGateway = {
    async deleteSharedData(userId) {
      calls.push(`shared:${userId}`);
      return 1;
    },
    async deleteAuthUser(userId) {
      calls.push(`auth:${userId}`);
    },
  };
  const revoker: AppleAuthorizationRevoker = {
    async revokeAuthorizationCode(request) {
      calls.push(
        `apple:${request.expectedSubject}:${request.authorizationCode}`,
      );
    },
  };

  await new AccountDeletionService(gateway, revoker).deleteAccount(
    'user-1',
    {
      appleSubject: ' apple-user-1 ',
      appleAuthorizationCode: ' authorization-code ',
    },
  );

  assert.deepEqual(calls, [
    'apple:apple-user-1:authorization-code',
    'shared:user-1',
    'auth:user-1',
  ]);
});

test('requires fresh Apple authorization before deleting account data', async () => {
  const calls: string[] = [];
  const gateway: AccountDeletionGateway = {
    async deleteSharedData() {
      calls.push('shared');
      return 0;
    },
    async deleteAuthUser() {
      calls.push('auth');
    },
  };
  const revoker: AppleAuthorizationRevoker = {
    async revokeAuthorizationCode() {
      calls.push('apple');
    },
  };

  await assert.rejects(
    () =>
      new AccountDeletionService(gateway, revoker).deleteAccount(
        'user-1',
        { appleSubject: 'apple-user-1' },
      ),
    /apple_reauthentication_required/,
  );
  assert.deepEqual(calls, []);
});

test('preserves account data when Apple token revocation fails', async () => {
  const calls: string[] = [];
  const gateway: AccountDeletionGateway = {
    async deleteSharedData() {
      calls.push('shared');
      return 0;
    },
    async deleteAuthUser() {
      calls.push('auth');
    },
  };
  const revoker: AppleAuthorizationRevoker = {
    async revokeAuthorizationCode() {
      calls.push('apple');
      throw new Error('apple_token_revocation_failed');
    },
  };

  await assert.rejects(
    () =>
      new AccountDeletionService(gateway, revoker).deleteAccount(
        'user-1',
        {
          appleSubject: 'apple-user-1',
          appleAuthorizationCode: 'authorization-code',
        },
      ),
    /apple_token_revocation_failed/,
  );
  assert.deepEqual(calls, ['apple']);
});
