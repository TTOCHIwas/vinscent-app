import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  ClaimedSafetyModerationAlert,
} from './safety_moderation_alert_contract.ts';
import {
  SafetyModerationWebhookDelivery,
} from './safety_moderation_webhook_delivery.ts';

const alert: ClaimedSafetyModerationAlert = {
  reportId: 'report-1',
  claimToken: 'claim-private',
  attemptCount: 1,
  maxAttempts: 5,
  targetType: 'calendar_event',
  reason: 'privacy',
  hasDetails: true,
  hasContentSnapshot: true,
  reportCreatedAt: '2026-07-29T00:00:00.000Z',
};

test('sends only the minimal moderation notification envelope', async () => {
  let receivedRequest: Request | undefined;
  const delivery = new SafetyModerationWebhookDelivery({
    endpoint: 'https://moderation.example.test/events',
    bearerToken: 'receiver-secret',
    fetchImpl: async (input, init) => {
      receivedRequest = new Request(input, init);
      return new Response(null, { status: 204 });
    },
  });

  await delivery.deliver(alert);

  assert.ok(receivedRequest);
  assert.equal(receivedRequest.headers.get('authorization'), 'Bearer receiver-secret');
  assert.equal(receivedRequest.headers.get('x-danjjan-event-id'), 'report-1');
  const body = await receivedRequest.json();
  assert.deepEqual(body, {
    type: 'danjjan.safety_report.created',
    version: 1,
    report: {
      id: 'report-1',
      targetType: 'calendar_event',
      reason: 'privacy',
      createdAt: '2026-07-29T00:00:00.000Z',
      hasDetails: true,
      hasContentSnapshot: true,
    },
  });
  const serialized = JSON.stringify(body);
  assert.equal(serialized.includes('claim-private'), false);
  assert.equal(serialized.includes('couple'), false);
  assert.equal(serialized.includes('content_snapshot'), false);
});

test('maps receiver failures to stable retry-safe error codes', async () => {
  const rateLimited = new SafetyModerationWebhookDelivery({
    endpoint: 'https://moderation.example.test/events',
    fetchImpl: async () => new Response(null, { status: 429 }),
  });
  const rejected = new SafetyModerationWebhookDelivery({
    endpoint: 'https://moderation.example.test/events',
    fetchImpl: async () => new Response(null, { status: 400 }),
  });

  await assert.rejects(
    () => rateLimited.deliver(alert),
    /moderation_webhook_rate_limited/,
  );
  await assert.rejects(
    () => rejected.deliver(alert),
    /moderation_webhook_rejected/,
  );
});

test('rejects non-HTTPS receiver endpoints', () => {
  assert.throws(
    () => new SafetyModerationWebhookDelivery({
      endpoint: 'http://moderation.example.test/events',
    }),
    /must use HTTPS/,
  );
});
