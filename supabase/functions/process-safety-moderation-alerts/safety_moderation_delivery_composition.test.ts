import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  ClaimedSafetyModerationAlert,
} from './safety_moderation_alert_contract.ts';
import {
  createSafetyModerationAlertDelivery,
} from './safety_moderation_delivery_composition.ts';

const alert: ClaimedSafetyModerationAlert = {
  reportId: 'report-1',
  claimToken: 'claim-private',
  attemptCount: 1,
  maxAttempts: 5,
  targetType: 'story_card',
  reason: 'inappropriate',
  hasDetails: true,
  hasContentSnapshot: false,
  reportCreatedAt: '2026-07-29T00:00:00.000Z',
};

test('prefers the dedicated Discord moderation webhook', async () => {
  let receivedRequest: Request | undefined;
  const values: Record<string, string> = {
    SAFETY_MODERATION_DISCORD_WEBHOOK_URL:
      'https://discord.com/api/webhooks/123456789/test-token',
    SAFETY_MODERATION_WEBHOOK_URL: 'https://generic.example.test/events',
  };
  const delivery = createSafetyModerationAlertDelivery({
    readEnvironment: (name) => values[name],
    fetchImpl: async (input, init) => {
      receivedRequest = new Request(input, init);
      return Response.json({ id: 'message-1' });
    },
  });

  await delivery.deliver(alert);

  assert.ok(receivedRequest);
  assert.equal(new URL(receivedRequest.url).hostname, 'discord.com');
  const body = await receivedRequest.json();
  assert.equal(body.username, '단짠 안전 신고');
});

test('preserves the generic receiver as a compatibility fallback', async () => {
  let receivedRequest: Request | undefined;
  const values: Record<string, string> = {
    SAFETY_MODERATION_WEBHOOK_URL: 'https://generic.example.test/events',
    SAFETY_MODERATION_WEBHOOK_BEARER_TOKEN: 'receiver-secret',
  };
  const delivery = createSafetyModerationAlertDelivery({
    readEnvironment: (name) => values[name],
    fetchImpl: async (input, init) => {
      receivedRequest = new Request(input, init);
      return new Response(null, { status: 204 });
    },
  });

  await delivery.deliver(alert);

  assert.ok(receivedRequest);
  assert.equal(new URL(receivedRequest.url).hostname, 'generic.example.test');
  assert.equal(
    receivedRequest.headers.get('authorization'),
    'Bearer receiver-secret',
  );
  const body = await receivedRequest.json();
  assert.equal(body.type, 'danjjan.safety_report.created');
});

test('rejects an unconfigured moderation receiver', () => {
  assert.throws(
    () => createSafetyModerationAlertDelivery({
      readEnvironment: () => undefined,
    }),
    /missing_env:SAFETY_MODERATION_WEBHOOK_URL/,
  );
});
