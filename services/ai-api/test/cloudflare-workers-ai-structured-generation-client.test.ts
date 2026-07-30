import assert from 'node:assert/strict';
import test from 'node:test';

import {
  StructuredGenerationError,
} from '../src/application/structured-generation-client.ts';
import {
  CloudflareWorkersAiStructuredGenerationClient,
} from '../src/infrastructure/cloudflare-workers-ai-structured-generation-client.ts';

const accountId = '0123456789abcdef0123456789abcdef';
const model = '@cf/meta/llama-3.1-8b-instruct-fast';

test('Cloudflare client sends JSON Schema mode and reports usage', async () => {
  let capturedUrl = '';
  let capturedInit: RequestInit | undefined;
  const clockValues = [1_000, 1_240];
  const client = new CloudflareWorkersAiStructuredGenerationClient({
    accountId,
    apiToken: 'test-api-token',
    model,
    now: () => clockValues.shift() ?? 1_240,
    fetcher: async (input, init) => {
      capturedUrl = String(input);
      capturedInit = init;
      return Response.json({
        result: {
          response: {
            feedback_text: '서로 다른 하루를 챙기는 방식이 귀엽네!',
          },
          usage: {
            prompt_tokens: 18,
            completion_tokens: 7,
          },
        },
        success: true,
        errors: [],
        messages: [],
      });
    },
  });
  const schema = {
    type: 'object',
    properties: {
      feedback_text: { type: 'string' },
    },
    required: ['feedback_text'],
    additionalProperties: false,
  };

  const result = await client.generateStructured({
    prompt: '한 줄 피드백을 만들어줘',
    schema,
  });

  assert.equal(
    capturedUrl,
    `https://api.cloudflare.com/client/v4/accounts/${accountId}`
      + `/ai/run/${model}`,
  );
  const headers = new Headers(capturedInit?.headers);
  assert.equal(headers.get('authorization'), 'Bearer test-api-token');
  assert.equal(headers.get('content-type'), 'application/json');
  const body = JSON.parse(String(capturedInit?.body));
  assert.deepEqual(body.messages, [
    { role: 'user', content: '한 줄 피드백을 만들어줘' },
  ]);
  assert.deepEqual(body.response_format, {
    type: 'json_schema',
    json_schema: schema,
  });
  assert.equal(body.stream, false);
  assert.equal(body.max_tokens, 1_024);
  assert.deepEqual(result, {
    value: {
      feedback_text: '서로 다른 하루를 챙기는 방식이 귀엽네!',
    },
    usage: {
      inputTokenCount: 18,
      outputTokenCount: 7,
      latencyMs: 240,
    },
  });
});

test('Cloudflare client parses a JSON string response', async () => {
  const client = new CloudflareWorkersAiStructuredGenerationClient({
    accountId,
    apiToken: 'test-api-token',
    model,
    fetcher: async () => Response.json({
      result: {
        response: '{"feedback_text":"오늘 답도 둘답다!"}',
      },
      success: true,
      errors: [],
      messages: [],
    }),
  });

  const result = await client.generateStructured({
    prompt: '한 줄 피드백을 만들어줘',
    schema: { type: 'object' },
  });

  assert.deepEqual(result.value, {
    feedback_text: '오늘 답도 둘답다!',
  });
});

test('Cloudflare client classifies daily allocation exhaustion as rate limited', async () => {
  const clockValues = [1_000, 1_275];
  const client = new CloudflareWorkersAiStructuredGenerationClient({
    accountId,
    apiToken: 'test-api-token',
    model,
    now: () => clockValues.shift() ?? 1_275,
    fetcher: async () => Response.json({
      result: null,
      success: false,
      errors: [{ code: 3036, message: 'Daily allocation exhausted' }],
      messages: [],
    }, {
      status: 429,
      headers: { 'retry-after': '30' },
    }),
  });

  await assert.rejects(
    () => client.generateStructured({
      prompt: '한 줄 피드백을 만들어줘',
      schema: { type: 'object' },
    }),
    (error: unknown) => {
      assert.ok(error instanceof StructuredGenerationError);
      assert.equal(error.code, 'rate_limited');
      assert.equal(error.retryable, true);
      assert.equal(error.providerHttpStatus, 429);
      assert.equal(error.providerErrorStatus, 'CF_3036');
      assert.equal(error.retryAfterMs, 30_000);
      assert.equal(error.usage.latencyMs, 275);
      return true;
    },
  );
});

test('Cloudflare client classifies capacity exhaustion as unavailable', async () => {
  const client = new CloudflareWorkersAiStructuredGenerationClient({
    accountId,
    apiToken: 'test-api-token',
    model,
    fetcher: async () => Response.json({
      result: null,
      success: false,
      errors: [{ code: 3040, message: 'Out of capacity' }],
      messages: [],
    }, { status: 429 }),
  });

  await assert.rejects(
    () => client.generateStructured({
      prompt: '한 줄 피드백을 만들어줘',
      schema: { type: 'object' },
    }),
    (error: unknown) => {
      assert.ok(error instanceof StructuredGenerationError);
      assert.equal(error.code, 'provider_unavailable');
      assert.equal(error.retryable, true);
      assert.equal(error.providerErrorStatus, 'CF_3040');
      return true;
    },
  );
});

test('Cloudflare client recognizes model errors returned with HTTP 400', async () => {
  const client = new CloudflareWorkersAiStructuredGenerationClient({
    accountId,
    apiToken: 'test-api-token',
    model,
    fetcher: async () => Response.json({
      result: null,
      success: false,
      errors: [{ code: 5007, message: 'No such model' }],
      messages: [],
    }, { status: 400 }),
  });

  await assert.rejects(
    () => client.generateStructured({
      prompt: '한 줄 피드백을 만들어줘',
      schema: { type: 'object' },
    }),
    (error: unknown) => {
      assert.ok(error instanceof StructuredGenerationError);
      assert.equal(error.code, 'model_not_found');
      assert.equal(error.retryable, false);
      assert.equal(error.providerErrorStatus, 'CF_5007');
      return true;
    },
  );
});

test('Cloudflare client rejects malformed structured output', async () => {
  const client = new CloudflareWorkersAiStructuredGenerationClient({
    accountId,
    apiToken: 'test-api-token',
    model,
    fetcher: async () => Response.json({
      result: { response: 'not-json' },
      success: true,
      errors: [],
      messages: [],
    }),
  });

  await assert.rejects(
    () => client.generateStructured({
      prompt: '한 줄 피드백을 만들어줘',
      schema: { type: 'object' },
    }),
    (error: unknown) => {
      assert.ok(error instanceof StructuredGenerationError);
      assert.equal(error.code, 'invalid_output');
      assert.equal(error.retryable, false);
      return true;
    },
  );
});

test('Cloudflare client classifies request aborts as retryable timeouts', async () => {
  const client = new CloudflareWorkersAiStructuredGenerationClient({
    accountId,
    apiToken: 'test-api-token',
    model,
    timeoutMs: 1,
    fetcher: async (_input, init) => {
      await new Promise<void>((_resolve, reject) => {
        init?.signal?.addEventListener('abort', () => {
          reject(new DOMException('Aborted', 'AbortError'));
        });
      });
      throw new Error('unreachable');
    },
  });

  await assert.rejects(
    () => client.generateStructured({
      prompt: '한 줄 피드백을 만들어줘',
      schema: { type: 'object' },
    }),
    (error: unknown) => {
      assert.ok(error instanceof StructuredGenerationError);
      assert.equal(error.code, 'timeout');
      assert.equal(error.retryable, true);
      return true;
    },
  );
});
