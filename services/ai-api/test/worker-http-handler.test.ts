import assert from 'node:assert/strict';
import test from 'node:test';

import { createLearningWorkerHttpHandler } from '../src/presentation/learning-worker-http-handler.ts';

test('worker handler accepts only an exact service role bearer token', async () => {
  let calls = 0;
  const handler = createLearningWorkerHttpHandler({
    serviceRoleKey: 'service-role-secret',
    processor: {
      async processBatch() {
        calls += 1;
        return { claimed: 0, succeeded: 0, retried: 0, failed: 0 };
      },
    },
  });

  const missing = await handler(new Request('https://example.test', {
    method: 'POST',
  }));
  const wrong = await handler(new Request('https://example.test', {
    method: 'POST',
    headers: { authorization: 'Bearer wrong-secret' },
  }));
  const accepted = await handler(new Request('https://example.test', {
    method: 'POST',
    headers: { authorization: 'Bearer service-role-secret' },
  }));

  assert.equal(missing.status, 401);
  assert.equal(wrong.status, 401);
  assert.equal(accepted.status, 200);
  assert.equal(calls, 1);
});

test('worker handler accepts an exact scheduler secret without exposing service role credentials', async () => {
  let calls = 0;
  const handler = createLearningWorkerHttpHandler({
    serviceRoleKey: 'service-role-secret',
    workerSecret: 'scheduler-secret',
    processor: {
      async processBatch() {
        calls += 1;
        return { claimed: 0, succeeded: 0, retried: 0, failed: 0 };
      },
    },
  });

  const wrong = await handler(new Request('https://example.test', {
    method: 'POST',
    headers: { 'x-ai-worker-secret': 'wrong-secret' },
  }));
  const accepted = await handler(new Request('https://example.test', {
    method: 'POST',
    headers: { 'x-ai-worker-secret': 'scheduler-secret' },
  }));

  assert.equal(wrong.status, 401);
  assert.equal(accepted.status, 200);
  assert.equal(calls, 1);
});

test('worker handler validates and caps the requested batch size', async () => {
  const receivedLimits: number[] = [];
  const handler = createLearningWorkerHttpHandler({
    serviceRoleKey: 'service-role-secret',
    processor: {
      async processBatch(limit) {
        receivedLimits.push(limit);
        return { claimed: 0, succeeded: 0, retried: 0, failed: 0 };
      },
    },
  });
  const request = (body: string) => new Request('https://example.test', {
    method: 'POST',
    headers: {
      authorization: 'Bearer service-role-secret',
      'content-type': 'application/json',
    },
    body,
  });

  const defaultResponse = await handler(request('{}'));
  const explicitResponse = await handler(request('{"limit":5}'));
  const tooLargeResponse = await handler(request('{"limit":6}'));
  const malformedResponse = await handler(request('{'));

  assert.equal(defaultResponse.status, 200);
  assert.equal(explicitResponse.status, 200);
  assert.equal(tooLargeResponse.status, 400);
  assert.equal(malformedResponse.status, 400);
  assert.deepEqual(receivedLimits, [3, 5]);
});

test('worker handler does not expose internal processing errors', async () => {
  const handler = createLearningWorkerHttpHandler({
    serviceRoleKey: 'service-role-secret',
    onError() {},
    processor: {
      async processBatch() {
        throw new Error('private answer text must never leave the server');
      },
    },
  });
  const response = await handler(new Request('https://example.test', {
    method: 'POST',
    headers: { authorization: 'Bearer service-role-secret' },
  }));
  const body = await response.json();

  assert.equal(response.status, 500);
  assert.deepEqual(body, { error: 'ai_worker_failed' });
  assert.equal(JSON.stringify(body).includes('private answer'), false);
});

test('worker handler rejects unsupported methods', async () => {
  const handler = createLearningWorkerHttpHandler({
    serviceRoleKey: 'service-role-secret',
    processor: {
      async processBatch() {
        return { claimed: 0, succeeded: 0, retried: 0, failed: 0 };
      },
    },
  });

  const response = await handler(new Request('https://example.test'));

  assert.equal(response.status, 405);
});
