import assert from 'node:assert/strict';
import test from 'node:test';
import { OpenAiContentSafetyProvider } from '../src/infrastructure/openai-content-safety-provider.ts';
import { CloudflareContentSafetyProvider } from '../src/infrastructure/cloudflare-content-safety-provider.ts';

const text = { id: 'text', kind: 'text' as const, text: '너와 함께라서 행복해.' };
const signal = () => new AbortController().signal;
const categories = { sexual: false, violence: false, hate: false };
const openAiResult = (flagged = false) => ({ id: 'modr-test', model: 'omni-moderation-latest', results: [{ flagged, categories: { ...categories, violence: flagged } }] });

test('OpenAI sends Korean text to the fixed moderation endpoint without identifiers', async () => {
  let body: unknown;
  const provider = new OpenAiContentSafetyProvider({ apiKey: 'test-token', fetcher: async (url, init) => {
    assert.equal(String(url), 'https://api.openai.com/v1/moderations');
    assert.equal(init?.redirect, 'error');
    body = JSON.parse(String(init?.body));
    return Response.json(openAiResult());
  } });
  assert.deepEqual(await provider.check(text, signal()), { decision: 'allow' });
  assert.deepEqual(body, { model: 'omni-moderation-latest', input: [{ type: 'text', text: text.text }] });
});

test('OpenAI embeds image bytes instead of exposing a private storage URL', async () => {
  let body: any;
  const provider = new OpenAiContentSafetyProvider({ apiKey: 'test', fetcher: async (_url, init) => {
    body = JSON.parse(String(init?.body)); return Response.json(openAiResult());
  } });
  await provider.check({ id: 'photo', kind: 'image', mimeType: 'image/png', bytes: new Uint8Array([1, 2, 3]) }, signal());
  assert.equal(body.input[0].image_url.url, 'data:image/png;base64,AQID');
});

test('OpenAI blocks if a category is true even when the top-level flag is false', async () => {
  const result = openAiResult(); result.results[0].categories.hate = true;
  const provider = new OpenAiContentSafetyProvider({ apiKey: 'test', fetcher: async () => Response.json(result) });
  assert.deepEqual(await provider.check(text, signal()), { decision: 'block' });
});

for (const result of [{ results: [] }, { results: [{ flagged: false }] }, { results: [{ flagged: false, categories: {} }] },
  { results: [{ flagged: false, categories: { violence: 'false' } }] }, { results: [{ flagged: true, categories }, { flagged: false, categories }] }]) {
  test('OpenAI rejects a missing, malformed or ambiguous classification', async () => {
    const provider = new OpenAiContentSafetyProvider({ apiKey: 'test', fetcher: async () => Response.json(result) });
    await assert.rejects(provider.check(text, signal()), /content_safety_invalid_response/);
  });
}

for (const status of [401, 429, 500]) {
  test(`OpenAI failure ${status} contains no upstream body or credentials`, async () => {
    const provider = new OpenAiContentSafetyProvider({ apiKey: 'secret-key', fetcher: async () => new Response('private content', { status }) });
    await assert.rejects(provider.check(text, signal()), { message: 'content_safety_provider_unavailable' });
  });
}

test('OpenAI refuses audio rather than treating unexamined speech as safe', async () => {
  const provider = new OpenAiContentSafetyProvider({ apiKey: 'test', fetcher: async () => { throw new Error('must not send'); } });
  await assert.rejects(provider.check({ id: 'voice', kind: 'audio', mimeType: 'audio/mp4', bytes: new Uint8Array([1]) }, signal()), /content_safety_unsupported_kind/);
});

test('Cloudflare sends the original Korean text and accepts only an explicit safe label', async () => {
  let body: any;
  const provider = new CloudflareContentSafetyProvider({ accountId: 'a'.repeat(32), apiToken: 'test', fetcher: async (url, init) => {
    assert.equal(String(url), `https://api.cloudflare.com/client/v4/accounts/${'a'.repeat(32)}/ai/run/@cf/meta/llama-guard-3-8b`);
    body = JSON.parse(String(init?.body)); return Response.json({ success: true, result: { response: 'safe' } });
  } });
  assert.deepEqual(await provider.check(text, signal()), { decision: 'allow' });
  assert.deepEqual(body.messages, [{ role: 'user', content: text.text }]);
});

test('Cloudflare converts a documented unsafe classification to block', async () => {
  const provider = new CloudflareContentSafetyProvider({ accountId: 'a'.repeat(32), apiToken: 'test', fetcher: async () => Response.json({ success: true, result: { response: 'unsafe\nS1,S2' } }) });
  assert.deepEqual(await provider.check(text, signal()), { decision: 'block' });
});

for (const response of ['not unsafe', 'probably safe', 'safe\nunsafe', '', 'unsafe\nunknown']) {
  test(`Cloudflare does not approve ambiguous output ${JSON.stringify(response)}`, async () => {
    const provider = new CloudflareContentSafetyProvider({ accountId: 'a'.repeat(32), apiToken: 'test', fetcher: async () => Response.json({ success: true, result: { response } }) });
    await assert.rejects(provider.check(text, signal()), /content_safety_invalid_response/);
  });
}

test('a provider error envelope is not a successful Cloudflare classification', async () => {
  const provider = new CloudflareContentSafetyProvider({ accountId: 'a'.repeat(32), apiToken: 'test', fetcher: async () => Response.json({ success: false, result: { response: 'safe' } }) });
  await assert.rejects(provider.check(text, signal()), /content_safety_invalid_response/);
});

test('empty credentials and malformed Cloudflare account IDs fail before any request', () => {
  assert.throws(() => new OpenAiContentSafetyProvider({ apiKey: ' ' }));
  assert.throws(() => new CloudflareContentSafetyProvider({ accountId: '../other', apiToken: 'test' }));
});
