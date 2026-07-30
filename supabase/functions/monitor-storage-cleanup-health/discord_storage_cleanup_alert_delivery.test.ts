import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  ClaimedStorageCleanupAlert,
} from './storage_cleanup_alert_contract.ts';
import {
  DiscordStorageCleanupAlertDelivery,
} from './discord_storage_cleanup_alert_delivery.ts';

const alert: ClaimedStorageCleanupAlert = {
  alertId: 'alert-private',
  incidentId: 'incident-1',
  claimToken: 'claim-private',
  attemptCount: 1,
  maxAttempts: 5,
  alertKind: 'degraded',
  issueCodes: ['failed_requests', 'cleanup_cron_stale'],
  failedRequestCount: 2,
  staleProcessingCount: 0,
  overduePendingCount: 0,
  cleanupCronStatus: 'stale',
  cleanupCronLastSucceededAt: '2026-07-30T00:00:00.000Z',
  detectedAt: '2026-07-30T00:20:00.000Z',
  incidentStartedAt: '2026-07-30T00:20:00.000Z',
};

test('sends a bounded Discord embed and confirms persistence', async () => {
  let receivedRequest: Request | undefined;
  const delivery = new DiscordStorageCleanupAlertDelivery({
    endpoint:
      'https://discordapp.com/api/webhooks/123456789/test-token',
    fetchImpl: async (input, init) => {
      receivedRequest = new Request(input, init);
      return Response.json({ id: 'message-1' });
    },
  });

  await delivery.deliver(alert);

  assert.ok(receivedRequest);
  assert.equal(receivedRequest.url.startsWith(
    'https://discord.com/api/webhooks/123456789/test-token',
  ), true);
  assert.equal(new URL(receivedRequest.url).searchParams.get('wait'), 'true');
  assert.equal(receivedRequest.redirect, 'error');
  const body = await receivedRequest.json();
  assert.deepEqual(body.allowed_mentions, { parse: [] });
  assert.equal(body.embeds.length, 1);
  assert.equal(body.embeds[0].title, 'Storage 정리 상태 이상');

  const serialized = JSON.stringify(body);
  assert.equal(serialized.includes('claim-private'), false);
  assert.equal(serialized.includes('alert-private'), false);
  assert.equal(serialized.includes('object_path'), false);
  assert.equal(serialized.includes('user_id'), false);
});

test('maps Discord rate limits and rejected webhooks separately', async () => {
  const rateLimited = new DiscordStorageCleanupAlertDelivery({
    endpoint: 'https://discord.com/api/webhooks/123456789/test-token',
    fetchImpl: async () =>
      new Response(null, {
        status: 429,
        headers: { 'retry-after': '2.4' },
      }),
  });
  const rejected = new DiscordStorageCleanupAlertDelivery({
    endpoint: 'https://discord.com/api/webhooks/123456789/test-token',
    fetchImpl: async () => new Response(null, { status: 404 }),
  });

  await assert.rejects(
    () => rateLimited.deliver(alert),
    (error) => {
      assert.equal(error.code, 'discord_webhook_rate_limited');
      assert.equal(error.retryable, true);
      assert.equal(error.retryAfterSeconds, 3);
      return true;
    },
  );
  await assert.rejects(
    () => rejected.deliver(alert),
    (error) => {
      assert.equal(error.code, 'discord_webhook_rejected');
      assert.equal(error.retryable, false);
      return true;
    },
  );
});

test('rejects non-Discord and malformed webhook endpoints', () => {
  assert.throws(
    () => new DiscordStorageCleanupAlertDelivery({
      endpoint: 'https://example.test/api/webhooks/123/token',
    }),
    /host is invalid/,
  );
  assert.throws(
    () => new DiscordStorageCleanupAlertDelivery({
      endpoint: 'https://discord.com/channels/123',
    }),
    /path is invalid/,
  );
});
