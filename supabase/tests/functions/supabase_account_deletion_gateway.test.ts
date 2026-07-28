import assert from 'node:assert/strict';
import test from 'node:test';

import {
  SupabaseAccountDeletionAuthenticator,
  SupabaseAccountDeletionGateway,
} from '../../functions/delete-account/supabase_account_deletion_gateway.ts';

test('authenticates a valid access token', async () => {
  let receivedToken: string | null = null;
  const client = createClient({
    async getUser(accessToken) {
      receivedToken = accessToken;
      return {
        data: { user: { id: ' user-1 ' } },
        error: null,
      };
    },
  });

  const identity = await new SupabaseAccountDeletionAuthenticator(
    client,
  ).authenticate('access-token');

  assert.equal(receivedToken, 'access-token');
  assert.deepEqual(identity, { userId: 'user-1' });
});

test('includes the verified Apple subject in the authenticated identity', async () => {
  const client = createClient({
    async getUser() {
      return {
        data: {
          user: {
            id: 'user-1',
            identities: [
              {
                provider: 'apple',
                id: 'apple-identity-id',
                identity_data: { sub: ' apple-user-1 ' },
              },
            ],
          },
        },
        error: null,
      };
    },
  });

  const identity = await new SupabaseAccountDeletionAuthenticator(
    client,
  ).authenticate('access-token');

  assert.deepEqual(identity, {
    userId: 'user-1',
    appleSubject: 'apple-user-1',
  });
});

test('does not expose identity data from other providers as an Apple subject', async () => {
  const client = createClient({
    async getUser() {
      return {
        data: {
          user: {
            id: 'user-1',
            identities: [
              {
                provider: 'kakao',
                id: 'kakao-identity-id',
                identity_data: { sub: 'kakao-user-1' },
              },
            ],
          },
        },
        error: null,
      };
    },
  });

  const identity = await new SupabaseAccountDeletionAuthenticator(
    client,
  ).authenticate('access-token');

  assert.deepEqual(identity, { userId: 'user-1' });
});

test('rejects an invalid Supabase session', async () => {
  const client = createClient({
    async getUser() {
      return {
        data: { user: null },
        error: { message: 'invalid jwt' },
      };
    },
  });

  const identity = await new SupabaseAccountDeletionAuthenticator(
    client,
  ).authenticate('invalid-token');

  assert.equal(identity, null);
});

test('deletes shared data through the service-only RPC', async () => {
  const rpcCalls: unknown[] = [];
  const client = createClient({
    async rpc(name, args) {
      rpcCalls.push({ name, args });
      return { data: 2, error: null };
    },
  });

  const count = await new SupabaseAccountDeletionGateway(
    client,
  ).deleteSharedData('user-1');

  assert.equal(count, 2);
  assert.deepEqual(rpcCalls, [{
    name: 'delete_account_shared_data',
    args: { target_user_id: 'user-1' },
  }]);
});

test('rejects shared data RPC errors and malformed results', async () => {
  const failedClient = createClient({
    async rpc() {
      return { data: null, error: { message: 'rpc failed' } };
    },
  });
  await assert.rejects(
    () =>
      new SupabaseAccountDeletionGateway(failedClient).deleteSharedData(
        'user-1',
      ),
    /account_shared_data_deletion_failed/,
  );

  const malformedClient = createClient({
    async rpc() {
      return { data: '2', error: null };
    },
  });
  await assert.rejects(
    () =>
      new SupabaseAccountDeletionGateway(malformedClient).deleteSharedData(
        'user-1',
      ),
    /account_shared_data_deletion_invalid_result/,
  );
});

test('hard deletes the Supabase authentication user', async () => {
  const deletedUserIds: string[] = [];
  const client = createClient({
    async deleteUser(userId) {
      deletedUserIds.push(userId);
      return { error: null };
    },
  });

  await new SupabaseAccountDeletionGateway(client).deleteAuthUser('user-1');

  assert.deepEqual(deletedUserIds, ['user-1']);
});

test('propagates Supabase authentication deletion errors', async () => {
  const client = createClient({
    async deleteUser() {
      return { error: { message: 'admin delete failed' } };
    },
  });

  await assert.rejects(
    () =>
      new SupabaseAccountDeletionGateway(client).deleteAuthUser('user-1'),
    /auth_user_deletion_failed/,
  );
});

function createClient(
  overrides: {
    getUser?: (
      accessToken: string,
    ) => Promise<{
      data: {
        user: {
          id: string;
          identities?: Array<{
            provider?: unknown;
            id?: unknown;
            identity_data?: unknown;
          }> | null;
        } | null;
      };
      error: unknown;
    }>;
    rpc?: (
      name: string,
      args: Record<string, unknown>,
    ) => PromiseLike<{ data: unknown; error: unknown }>;
    deleteUser?: (
      userId: string,
    ) => Promise<{ error: unknown }>;
  } = {},
) {
  return {
    auth: {
      getUser: overrides.getUser ?? (async () => ({
        data: { user: { id: 'user-1' } },
        error: null,
      })),
      admin: {
        deleteUser: overrides.deleteUser ?? (async () => ({ error: null })),
      },
    },
    rpc: overrides.rpc ?? (async () => ({ data: 0, error: null })),
  };
}
