import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createSafetyModerationWorkerHttpHandler,
} from './safety_moderation_worker_http_handler.ts';

test('validates and caps moderation worker batch requests', async () => {
  const limits: number[] = [];
  const handler = createSafetyModerationWorkerHttpHandler({
    maximumBatchSize: 10,
    processor: {
      async processBatch(limit) {
        limits.push(limit);
        return {
          claimed: 0,
          delivered: 0,
          retried: 0,
          failed: 0,
          stale: 0,
        };
      },
    },
  });

  const defaultResponse = await handler(new Request('https://example.test', {
    method: 'POST',
  }));
  const cappedResponse = await handler(new Request('https://example.test', {
    method: 'POST',
    body: '{"limit":50}',
  }));
  const invalidResponse = await handler(new Request('https://example.test', {
    method: 'POST',
    body: '{"limit":0}',
  }));

  assert.equal(defaultResponse.status, 200);
  assert.equal(cappedResponse.status, 200);
  assert.equal(invalidResponse.status, 400);
  assert.deepEqual(limits, [10, 10]);
});

test('returns stable errors without exposing moderation data', async () => {
  const logs: Array<[string, string]> = [];
  const handler = createSafetyModerationWorkerHttpHandler({
    onError: (code, errorType) => logs.push([code, errorType]),
    processor: {
      async processBatch() {
        throw new Error('private report details');
      },
    },
  });

  const response = await handler(new Request('https://example.test', {
    method: 'POST',
  }));
  const body = await response.json();

  assert.equal(response.status, 500);
  assert.deepEqual(body, { error: 'safety_moderation_worker_failed' });
  assert.equal(JSON.stringify(body).includes('private report'), false);
  assert.deepEqual(logs, [[
    'safety_moderation_worker_failed',
    'Error',
  ]]);
});

test('rejects unsupported methods before processing', async () => {
  let calls = 0;
  const handler = createSafetyModerationWorkerHttpHandler({
    processor: {
      async processBatch() {
        calls += 1;
        return {
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
