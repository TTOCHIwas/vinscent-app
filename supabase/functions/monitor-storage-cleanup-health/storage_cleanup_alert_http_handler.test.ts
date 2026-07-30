import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createStorageCleanupAlertHttpHandler,
} from './storage_cleanup_alert_http_handler.ts';

test('validates and caps storage cleanup alert batch requests', async () => {
  const limits: number[] = [];
  const handler = createStorageCleanupAlertHttpHandler({
    maximumBatchSize: 10,
    processor: {
      async processBatch(limit) {
        limits.push(limit);
        return {
          healthStatus: 'healthy',
          issueCodes: [],
          queued: 0,
          claimed: 0,
          delivered: 0,
          retried: 0,
          failed: 0,
          stale: 0,
        };
      },
    },
  });

  const defaultResponse = await handler(new Request(
    'https://example.test',
    { method: 'POST' },
  ));
  const cappedResponse = await handler(new Request(
    'https://example.test',
    { method: 'POST', body: '{"limit":50}' },
  ));
  const invalidResponse = await handler(new Request(
    'https://example.test',
    { method: 'POST', body: '{"limit":0}' },
  ));

  assert.equal(defaultResponse.status, 200);
  assert.equal(cappedResponse.status, 200);
  assert.equal(invalidResponse.status, 400);
  assert.deepEqual(limits, [10, 10]);
});

test('returns stable errors without exposing operational details', async () => {
  const logs: Array<[string, string]> = [];
  const handler = createStorageCleanupAlertHttpHandler({
    onError: (code, errorType) => logs.push([code, errorType]),
    processor: {
      async processBatch() {
        throw new Error('private webhook token');
      },
    },
  });

  const response = await handler(new Request('https://example.test', {
    method: 'POST',
  }));
  const body = await response.json();

  assert.equal(response.status, 500);
  assert.deepEqual(body, {
    error: 'storage_cleanup_alert_worker_failed',
  });
  assert.equal(JSON.stringify(body).includes('private webhook'), false);
  assert.deepEqual(logs, [[
    'storage_cleanup_alert_worker_failed',
    'Error',
  ]]);
});

test('rejects unsupported methods before processing', async () => {
  let calls = 0;
  const handler = createStorageCleanupAlertHttpHandler({
    processor: {
      async processBatch() {
        calls += 1;
        return {
          healthStatus: 'healthy',
          issueCodes: [],
          queued: 0,
          claimed: 0,
          delivered: 0,
          retried: 0,
          failed: 0,
          stale: 0,
        };
      },
    },
  });

  const response = await handler(new Request('https://example.test'));

  assert.equal(response.status, 405);
  assert.equal(calls, 0);
});
