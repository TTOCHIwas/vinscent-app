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
  let receivedOptions: unknown;
  const handler = createHandler({
    authenticator: {
      async authenticate(accessToken) {
        receivedToken = accessToken;
        return { userId: 'user-1' };
      },
    },
    deletionService: {
      async deleteAccount(userId, options) {
        receivedUserId = userId;
        receivedOptions = options;
        return { deletedCoupleCount: 2 };
      },
    },
  });

  const response = await handler(authorizedRequest());

  assert.equal(response.status, 200);
  assert.equal(receivedToken, 'access-token');
  assert.equal(receivedUserId, 'user-1');
  assert.deepEqual(receivedOptions, {});
  assert.deepEqual(await response.json(), {
    status: 'deleted',
    deletedCoupleCount: 2,
  });
});

test('passes a fresh Apple authorization code with the verified subject', async () => {
  let receivedRequest: unknown;
  const handler = createHandler({
    authenticator: {
      async authenticate() {
        return {
          userId: 'user-1',
          appleSubject: 'apple-user-1',
        };
      },
    },
    deletionService: {
      async deleteAccount(userId, options) {
        receivedRequest = { userId, options };
        return { deletedCoupleCount: 1 };
      },
    },
  });

  const response = await handler(authorizedRequest({
    appleAuthorizationCode: ' authorization-code ',
  }));

  assert.equal(response.status, 200);
  assert.deepEqual(receivedRequest, {
    userId: 'user-1',
    options: {
      appleSubject: 'apple-user-1',
      appleAuthorizationCode: 'authorization-code',
    },
  });
});

test('rejects malformed deletion request bodies', async () => {
  let deletionCalled = false;
  const handler = createHandler({
    deletionService: {
      async deleteAccount() {
        deletionCalled = true;
        return { deletedCoupleCount: 0 };
      },
    },
  });

  const response = await handler(authorizedRequest({
    appleAuthorizationCode: 123,
  }));

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: 'invalid_request',
  });
  assert.equal(deletionCalled, false);
});

test('exposes the Apple reauthentication requirement without deleting', async () => {
  const handler = createHandler({
    deletionService: {
      async deleteAccount() {
        throw new Error('apple_reauthentication_required');
      },
    },
  });

  const response = await handler(authorizedRequest());

  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), {
    error: 'apple_reauthentication_required',
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

function authorizedRequest(body?: Record<string, unknown>) {
  return new Request('https://example.test/delete-account', {
    method: 'POST',
    headers: { authorization: 'Bearer access-token' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

function createHandler(
  overrides: {
    authenticator?: AccountDeletionAuthenticator;
    deletionService?: {
      deleteAccount(
        userId: string,
        options?: {
          appleSubject?: string;
          appleAuthorizationCode?: string;
        },
      ): Promise<{ deletedCoupleCount: number }>;
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
