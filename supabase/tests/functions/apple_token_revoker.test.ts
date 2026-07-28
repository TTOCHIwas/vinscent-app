import assert from 'node:assert/strict';
import test from 'node:test';

import { AppleTokenRevoker } from '../../functions/delete-account/apple_token_revoker.ts';

test('exchanges the authorization code and revokes the matching refresh token', async () => {
  const requests: Array<{ url: string; body: URLSearchParams }> = [];
  const revoker = new AppleTokenRevoker({
    clientId: 'com.vinscent.vinscent',
    createClientSecret: async () => 'client-secret',
    fetch: async (input, init) => {
      const url = input.toString();
      requests.push({
        url,
        body: new URLSearchParams(init?.body?.toString()),
      });
      if (url.endsWith('/auth/token')) {
        return Response.json({
          access_token: 'access-token',
          refresh_token: 'refresh-token',
          id_token: unsignedJwt({ sub: 'apple-user-1' }),
        });
      }
      return new Response(null, { status: 200 });
    },
  });

  await revoker.revokeAuthorizationCode({
    authorizationCode: ' authorization-code ',
    expectedSubject: 'apple-user-1',
  });

  assert.equal(requests.length, 2);
  assert.equal(requests[0].url, 'https://appleid.apple.com/auth/token');
  assert.deepEqual(Object.fromEntries(requests[0].body), {
    client_id: 'com.vinscent.vinscent',
    client_secret: 'client-secret',
    code: 'authorization-code',
    grant_type: 'authorization_code',
  });
  assert.equal(requests[1].url, 'https://appleid.apple.com/auth/revoke');
  assert.deepEqual(Object.fromEntries(requests[1].body), {
    client_id: 'com.vinscent.vinscent',
    client_secret: 'client-secret',
    token: 'refresh-token',
    token_type_hint: 'refresh_token',
  });
});

test('rejects an authorization code issued for another Apple subject', async () => {
  let revokeCalled = false;
  const revoker = new AppleTokenRevoker({
    clientId: 'com.vinscent.vinscent',
    createClientSecret: async () => 'client-secret',
    fetch: async (input) => {
      if (input.toString().endsWith('/auth/revoke')) {
        revokeCalled = true;
      }
      return Response.json({
        access_token: 'access-token',
        refresh_token: 'refresh-token',
        id_token: unsignedJwt({ sub: 'another-apple-user' }),
      });
    },
  });

  await assert.rejects(
    () =>
      revoker.revokeAuthorizationCode({
        authorizationCode: 'authorization-code',
        expectedSubject: 'apple-user-1',
      }),
    /apple_identity_mismatch/,
  );
  assert.equal(revokeCalled, false);
});

test('rejects failed Apple token exchange responses', async () => {
  const revoker = new AppleTokenRevoker({
    clientId: 'com.vinscent.vinscent',
    createClientSecret: async () => 'client-secret',
    fetch: async () =>
      Response.json({ error: 'invalid_grant' }, { status: 400 }),
  });

  await assert.rejects(
    () =>
      revoker.revokeAuthorizationCode({
        authorizationCode: 'authorization-code',
        expectedSubject: 'apple-user-1',
      }),
    /apple_token_exchange_failed/,
  );
});

test('rejects malformed Apple token responses', async () => {
  const revoker = new AppleTokenRevoker({
    clientId: 'com.vinscent.vinscent',
    createClientSecret: async () => 'client-secret',
    fetch: async () => Response.json({ access_token: 'access-token' }),
  });

  await assert.rejects(
    () =>
      revoker.revokeAuthorizationCode({
        authorizationCode: 'authorization-code',
        expectedSubject: 'apple-user-1',
      }),
    /apple_token_response_invalid/,
  );
});

function unsignedJwt(payload: Record<string, unknown>) {
  const encode = (value: unknown) =>
    Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({ alg: 'none' })}.${encode(payload)}.`;
}
