import assert from 'node:assert/strict';
import test from 'node:test';

import {
  CloudflareWorkersAiQuestionSimilarityClient,
} from '../src/infrastructure/cloudflare-workers-ai-question-similarity-client.ts';

test('Cloudflare question similarity client preserves context order', async () => {
  let capturedUrl = '';
  let capturedInit: RequestInit | undefined;
  const client = new CloudflareWorkersAiQuestionSimilarityClient({
    accountId: '0123456789abcdef0123456789abcdef',
    apiToken: 'test-token',
    fetcher: async (input, init) => {
      capturedUrl = String(input);
      capturedInit = init;
      return new Response(JSON.stringify({
        success: true,
        result: {
          response: [
            { id: 1, score: 0.24 },
            { id: 0, score: 0.91 },
          ],
        },
      }), { status: 200 });
    },
  });

  const scores = await client.score('같이 보고 싶은 영화는 뭐야?', [
    '영화관에서 좋아하는 장르는 뭐야?',
    '둘이 먹고 싶은 메뉴는 뭐야?',
  ]);

  assert.deepEqual(scores, [0.91, 0.24]);
  assert.equal(
    capturedUrl,
    'https://api.cloudflare.com/client/v4/accounts/'
      + '0123456789abcdef0123456789abcdef/ai/run/@cf/baai/bge-m3',
  );
  assert.equal(capturedInit?.method, 'POST');
  assert.equal(
    new Headers(capturedInit?.headers).get('authorization'),
    'Bearer test-token',
  );
  assert.deepEqual(JSON.parse(String(capturedInit?.body)), {
    query: '같이 보고 싶은 영화는 뭐야?',
    contexts: [
      { text: '영화관에서 좋아하는 장르는 뭐야?' },
      { text: '둘이 먹고 싶은 메뉴는 뭐야?' },
    ],
    truncate_inputs: false,
  });
});

test('Cloudflare question similarity client rejects incomplete score responses', async () => {
  const client = new CloudflareWorkersAiQuestionSimilarityClient({
    accountId: '0123456789abcdef0123456789abcdef',
    apiToken: 'test-token',
    fetcher: async () =>
      new Response(JSON.stringify({
        success: true,
        result: { response: [{ id: 0, score: 0.91 }] },
      }), { status: 200 }),
  });

  await assert.rejects(
    () => client.score('질문', ['비교 질문 하나', '비교 질문 둘']),
    /invalid similarity response/,
  );
});
