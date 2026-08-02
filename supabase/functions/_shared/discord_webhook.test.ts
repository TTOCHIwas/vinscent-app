import assert from 'node:assert/strict';
import test from 'node:test';

import {
  DiscordWebhookClient,
  DiscordWebhookRequestError,
} from './discord_webhook.ts';

test('normalizes Discord webhook endpoints and waits for persistence', async () => {
  let receivedRequest: Request | undefined;
  const client = new DiscordWebhookClient({
    endpoint: 'https://discordapp.com/api/webhooks/123456789/test-token',
    fetchImpl: async (input, init) => {
      receivedRequest = new Request(input, init);
      return Response.json({ id: 'message-1' });
    },
  });

  await client.send({ content: 'test' });

  assert.ok(receivedRequest);
  const endpoint = new URL(receivedRequest.url);
  assert.equal(endpoint.hostname, 'discord.com');
  assert.equal(endpoint.searchParams.get('wait'), 'true');
  assert.equal(receivedRequest.redirect, 'error');
  assert.deepEqual(await receivedRequest.json(), { content: 'test' });
});

test('returns stable Discord failure kinds and retry timing', async () => {
  const rateLimited = new DiscordWebhookClient({
    endpoint: 'https://discord.com/api/webhooks/123456789/test-token',
    fetchImpl: async () =>
      new Response(null, {
        status: 429,
        headers: { 'retry-after': '2.4' },
      }),
  });
  const rejected = new DiscordWebhookClient({
    endpoint: 'https://discord.com/api/webhooks/123456789/test-token',
    fetchImpl: async () => new Response(null, { status: 404 }),
  });

  await assert.rejects(
    () => rateLimited.send({ content: 'test' }),
    (error) => {
      assert.ok(error instanceof DiscordWebhookRequestError);
      assert.equal(error.kind, 'rate_limited');
      assert.equal(error.retryAfterSeconds, 3);
      return true;
    },
  );
  await assert.rejects(
    () => rejected.send({ content: 'test' }),
    (error) => {
      assert.ok(error instanceof DiscordWebhookRequestError);
      assert.equal(error.kind, 'rejected');
      return true;
    },
  );
});

test('rejects non-Discord and malformed webhook endpoints', () => {
  assert.throws(
    () => new DiscordWebhookClient({
      endpoint: 'https://example.test/api/webhooks/123/token',
    }),
    /host is invalid/,
  );
  assert.throws(
    () => new DiscordWebhookClient({
      endpoint: 'https://discord.com/channels/123',
    }),
    /path is invalid/,
  );
});
