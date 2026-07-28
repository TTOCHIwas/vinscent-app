import assert from 'node:assert/strict';
import test from 'node:test';

import { AppleClientSecretSigner } from '../../functions/delete-account/apple_client_secret.ts';

test('creates a verifiable Apple client secret with the required claims', async () => {
  const keys = await crypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    true,
    ['sign', 'verify'],
  );
  const privateKey = pemFrom(
    await crypto.subtle.exportKey('pkcs8', keys.privateKey),
  );
  const now = new Date('2026-07-29T03:00:00.000Z');
  const signer = new AppleClientSecretSigner({
    teamId: 'TEAM123',
    keyId: 'KEY123',
    clientId: 'com.vinscent.vinscent',
    privateKey,
    now: () => now,
  });

  const token = await signer.createClientSecret();
  const [headerSegment, payloadSegment, signatureSegment] = token.split('.');

  assert.deepEqual(readSegment(headerSegment), {
    alg: 'ES256',
    kid: 'KEY123',
    typ: 'JWT',
  });
  assert.deepEqual(readSegment(payloadSegment), {
    iss: 'TEAM123',
    iat: 1785294000,
    exp: 1785294300,
    aud: 'https://appleid.apple.com',
    sub: 'com.vinscent.vinscent',
  });
  assert.equal(
    await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      keys.publicKey,
      Buffer.from(signatureSegment, 'base64url'),
      new TextEncoder().encode(`${headerSegment}.${payloadSegment}`),
    ),
    true,
  );
});

test('rejects incomplete Apple client secret configuration', async () => {
  const signer = new AppleClientSecretSigner({
    teamId: ' ',
    keyId: 'KEY123',
    clientId: 'com.vinscent.vinscent',
    privateKey: 'private-key',
  });

  await assert.rejects(
    () => signer.createClientSecret(),
    /apple_team_id_required/,
  );
});

function pemFrom(key: ArrayBuffer) {
  const body = Buffer.from(key).toString('base64').match(/.{1,64}/g)?.join(
    '\n',
  );
  return `-----BEGIN PRIVATE KEY-----\n${body}\n-----END PRIVATE KEY-----`;
}

function readSegment(segment: string) {
  return JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'));
}
