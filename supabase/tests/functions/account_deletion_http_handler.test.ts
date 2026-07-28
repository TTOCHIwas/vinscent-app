import assert from 'node:assert/strict';
import test from 'node:test';

import {
  type AccountDeletionAuthenticator,
  createAccountDeletionHttpHandler,
} from '../../functions/delete-account/account_deletion_http_handler.ts';

test('rejects methods other than POST', async () => {
  const handler = createHandler();

  const response = await handler(
    new Request('https://example.test/delete-account', { method: 'GET' }),
  );

  assert.equal(response.status, 405);
  assert.equal(response.headers.get('allow'), 'POST');
  assert.deepEqual(await response.json(), { error: 'method_not_allowed' });
});

test('rejects a request without a bearer token', async () => {
  const handler = createHandler();

  const response = await handler(
    new Request('https://example.test/delete-account', { method: 'POST' }),
  );

  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: 'unauthorized' });
});

test('rejects an invalid access token', async () => {
  const handler = createHandler({
    authenticator: {
      async authenticate() {
        return null;
      },
    },
  });

  const response = await handler(authorizedRequest());

  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: 'unauthorized' });
});

test('deletes the authenticated account and returns the result', async () => {
  let receivedToken: string | null = null;
  let receivedUserId: string | null = null;
  const handler = createHandler({
    authenticator: {
      async authenticate(accessToken) {
        receivedToken = accessToken;
        return { userId: 'user-1' };
      },
    },
    deletionService: {
      async deleteAccount(userId) {
        receivedUserId = userId;
        return { deletedCoupleCount: 2 };
      },
    },
  });

  const response = await handler(authorizedRequest());

  assert.equal(response.status, 200);
  assert.equal(receivedToken, 'access-token');
  assert.equal(receivedUserId, 'user-1');
  assert.deepEqual(await response.json(), {
    status: 'deleted',
    deletedCoupleCount: 2,
  });
});

test('does not expose internal deletion errors', async () => {
  const errors: unknown[] = [];
  const handler = createHandler({
    deletionService: {
      async deleteAccount() {
        throw new Error('service role details');
      },
    },
    onError(error) {
      errors.push(error);
    },
  });

  const response = await handler(authorizedRequest());

  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), {
    error: 'account_deletion_failed',
  });
  assert.equal(errors.length, 1);
});

function authorizedRequest() {
  return new Request('https://example.test/delete-account', {
    method: 'POST',
    headers: { authorization: 'Bearer access-token' },
  });
}

function createHandler(
  overrides: {
    authenticator?: AccountDeletionAuthenticator;
    deletionService?: {
      deleteAccount(userId: string): Promise<{ deletedCoupleCount: number }>;
    };
    onError?: (error: unknown) => void;
  } = {},
) {
  return createAccountDeletionHttpHandler({
    authenticator: overrides.authenticator ?? {
      async authenticate() {
        return { userId: 'user-1' };
      },
    },
    deletionService: overrides.deletionService ?? {
      async deleteAccount() {
        return { deletedCoupleCount: 0 };
      },
    },
    onError: overrides.onError,
  });
}
