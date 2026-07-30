import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createStorageCleanupHttpHandler,
} from './storage_cleanup_http_handler.ts';

test('keeps database webhook requests on the single-request path', async () => {
  const requestIds: string[] = [];
  const handler = createStorageCleanupHttpHandler({
    processor: {
      async processRequest(requestId) {
        requestIds.push(requestId);
        return {
          status: 'completed',
          outcome: 'deleted',
          bucketId: 'story-cards',
          objectPath: 'old/preview.png',
          cleanupReason: 'orphan_story_card',
        };
      },
      async processBatch() {
        throw new Error('batch path should not run');
      },
    },
  });

  const response = await handler(new Request('https://example.test', {
    method: 'POST',
    body: JSON.stringify({
      record: { id: '10000000-0000-0000-0000-000000000001' },
    }),
  }));

  assert.equal(response.status, 200);
  assert.deepEqual(requestIds, [
    '10000000-0000-0000-0000-000000000001',
  ]);
  assert.deepEqual(await response.json(), {
    status: 'completed',
    outcome: 'deleted',
    bucketId: 'story-cards',
    objectPath: 'old/preview.png',
    cleanupReason: 'orphan_story_card',
  });
});

test('validates and caps scheduled batch requests', async () => {
  const options: unknown[] = [];
  const handler = createStorageCleanupHttpHandler({
    maximumBatchSize: 20,
    maximumReconcileBatchSize: 100,
    minimumReconcileAgeMinutes: 60,
    processor: {
      async processRequest() {
        throw new Error('single path should not run');
      },
      async processBatch(received) {
        options.push(received);
        return {
          reconciled: 0,
          claimed: 0,
          deleted: 0,
          preserved: 0,
          retried: 0,
          failed: 0,
          stale: 0,
        };
      },
    },
  });

  const response = await handler(new Request('https://example.test', {
    method: 'POST',
    body: '{"limit":50,"reconcileLimit":500}',
  }));

  assert.equal(response.status, 200);
  assert.deepEqual(options, [{
    limit: 20,
    reconcileLimit: 100,
    minimumAgeMinutes: 60,
  }]);
});

test('rejects malformed cleanup payloads', async () => {
  let calls = 0;
  const handler = createStorageCleanupHttpHandler({
    processor: {
      async processRequest() {
        calls += 1;
        throw new Error('not reached');
      },
      async processBatch() {
        calls += 1;
        throw new Error('not reached');
      },
    },
  });

  const response = await handler(new Request('https://example.test', {
    method: 'POST',
    body: '{"limit":0}',
  }));

  assert.equal(response.status, 400);
  assert.equal(calls, 0);
});

test('rejects database webhooks without a request id', async () => {
  let calls = 0;
  const handler = createStorageCleanupHttpHandler({
    processor: {
      async processRequest() {
        calls += 1;
        throw new Error('not reached');
      },
      async processBatch() {
        calls += 1;
        throw new Error('not reached');
      },
    },
  });

  const response = await handler(new Request('https://example.test', {
    method: 'POST',
    body: '{"record":{}}',
  }));

  assert.equal(response.status, 400);
  assert.equal(calls, 0);
});
