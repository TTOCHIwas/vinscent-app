import assert from 'node:assert/strict';
import test from 'node:test';

import {
  extractWebhookRecordId,
  internalErrorResponse,
  invalidPayloadResponse,
  isRecord,
  jsonResponse,
  verifyWebhookSecret,
} from '../../functions/_shared/webhook.ts';

test('extracts a webhook record id from nested and direct payloads', () => {
  assert.equal(extractWebhookRecordId({ record: { id: 'nested-id' } }), 'nested-id');
  assert.equal(extractWebhookRecordId({ id: 'direct-id' }), 'direct-id');
});

test('rejects webhook payloads without a non-empty id', () => {
  assert.throws(() => extractWebhookRecordId(null), /payload must be an object/);
  assert.throws(() => extractWebhookRecordId({ record: {} }), /missing id/);
  assert.throws(() => extractWebhookRecordId({ id: '' }), /missing id/);
});

test('accepts the configured primary or fallback webhook secret', () => {
  const env = new Map([
    ['PRIMARY_SECRET', 'primary'],
    ['FALLBACK_SECRET', 'fallback'],
  ]);
  const readEnv = (name: string) => env.get(name);

  assert.equal(
    verifyWebhookSecret(
      new Request('https://example.com', {
        headers: { 'x-primary-secret': 'primary' },
      }),
      {
        envName: 'PRIMARY_SECRET',
        headerName: 'x-primary-secret',
      },
      readEnv,
    ),
    true,
  );
  assert.equal(
    verifyWebhookSecret(
      new Request('https://example.com', {
        headers: { 'x-fallback-secret': 'fallback' },
      }),
      {
        envName: 'MISSING_PRIMARY_SECRET',
        headerName: 'x-primary-secret',
        fallbackEnvName: 'FALLBACK_SECRET',
        fallbackHeaderName: 'x-fallback-secret',
      },
      readEnv,
    ),
    true,
  );
  assert.equal(
    verifyWebhookSecret(
      new Request('https://example.com', {
        headers: { 'x-primary-secret': 'wrong' },
      }),
      {
        envName: 'PRIMARY_SECRET',
        headerName: 'x-primary-secret',
      },
      readEnv,
    ),
    false,
  );
});

test('creates JSON responses and identifies object records', async () => {
  const response = jsonResponse({ status: 'ok' }, 202);

  assert.equal(response.status, 202);
  assert.equal(response.headers.get('content-type'), 'application/json');
  assert.deepEqual(await response.json(), { status: 'ok' });
  assert.equal(isRecord({}), true);
  assert.equal(isRecord([]), false);
  assert.equal(isRecord(null), false);
});

test('returns stable webhook errors without exposing internal messages', async () => {
  const invalidPayload = invalidPayloadResponse();
  const logs: Array<[string, string]> = [];
  const internalFailure = internalErrorResponse(
    'operation_failed',
    new Error('database_query_failed:sensitive database detail'),
    (code, errorType) => logs.push([code, errorType]),
  );

  assert.equal(invalidPayload.status, 400);
  assert.deepEqual(await invalidPayload.json(), {
    error: 'invalid_payload',
  });
  assert.equal(internalFailure.status, 500);
  assert.deepEqual(await internalFailure.json(), {
    error: 'operation_failed',
  });
  assert.deepEqual(logs, [['operation_failed', 'database_query_failed']]);
  assert.equal(
    JSON.stringify(logs).includes('sensitive database detail'),
    false,
  );
});
