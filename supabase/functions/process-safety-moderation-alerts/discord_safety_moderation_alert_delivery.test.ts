import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  ClaimedSafetyModerationAlert,
} from './safety_moderation_alert_contract.ts';
import {
  DiscordSafetyModerationAlertDelivery,
} from './discord_safety_moderation_alert_delivery.ts';

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

test('sends a minimal Korean Discord moderation notice', async () => {
  let receivedRequest: Request | undefined;
  const delivery = new DiscordSafetyModerationAlertDelivery({
    endpoint: 'https://discord.com/api/webhooks/123456789/test-token',
    fetchImpl: async (input, init) => {
      receivedRequest = new Request(input, init);
      return Response.json({ id: 'message-1' });
    },
  });

  await delivery.deliver(alert);

  assert.ok(receivedRequest);
  const body = await receivedRequest.json();
  assert.equal(body.username, '단짠 안전 신고');
  assert.deepEqual(body.allowed_mentions, { parse: [] });
  assert.equal(body.embeds.length, 1);
  assert.equal(body.embeds[0].title, '새로운 신고가 접수됐어요');
  assert.deepEqual(body.embeds[0].fields, [
    { name: '대상', value: '일정', inline: true },
    { name: '사유', value: '개인정보 침해', inline: true },
    { name: '상세 내용', value: '있음', inline: true },
    { name: '콘텐츠 보관본', value: '있음', inline: true },
  ]);
  assert.equal(body.embeds[0].footer.text, '신고 ID report-1');
  assert.equal(body.embeds[0].timestamp, alert.reportCreatedAt);

  const serialized = JSON.stringify(body);
  assert.equal(serialized.includes('claim-private'), false);
  assert.equal(serialized.includes('content_snapshot'), false);
  assert.equal(serialized.includes('user_id'), false);
  assert.equal(serialized.includes('@everyone'), false);
});

test('keeps unknown server values readable without exposing content', async () => {
  let receivedBody: Record<string, unknown> | undefined;
  const delivery = new DiscordSafetyModerationAlertDelivery({
    endpoint: 'https://discord.com/api/webhooks/123456789/test-token',
    fetchImpl: async (_input, init) => {
      receivedBody = JSON.parse(String(init?.body));
      return Response.json({ id: 'message-1' });
    },
  });

  await delivery.deliver({
    ...alert,
    targetType: 'future_target',
    reason: 'future_reason',
    hasDetails: false,
    hasContentSnapshot: false,
  });

  const embed = (receivedBody?.embeds as Array<Record<string, unknown>>)[0];
  assert.deepEqual(embed.fields, [
    { name: '대상', value: 'future_target', inline: true },
    { name: '사유', value: 'future_reason', inline: true },
    { name: '상세 내용', value: '없음', inline: true },
    { name: '콘텐츠 보관본', value: '없음', inline: true },
  ]);
});
