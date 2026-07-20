import assert from 'node:assert/strict';
import test from 'node:test';

import {
  GeminiInteractionsClient,
  GeminiOutputError,
  GeminiProviderError,
} from '../src/infrastructure/gemini-interactions-client.ts';
import { GeminiLearningModel } from '../src/infrastructure/gemini-learning-model.ts';
import type {
  AnonymizedCompletedQuestionContext,
} from '../src/domain/learning-contract.ts';

const context: AnonymizedCompletedQuestionContext = {
  question: {
    dailyQuestionId: 'daily-question-1',
    questionId: 'question-1',
    text: 'What kind of time together feels most meaningful?',
    domain: 'personal_values',
  },
  answers: [
    {
      answerId: 'answer-a',
      participantKey: 'partner_a',
      text: 'Quiet time at home matters to me.',
    },
    {
      answerId: 'answer-b',
      participantKey: 'partner_b',
      text: 'Trying a new place together matters to me.',
    },
  ],
  confirmedMemories: [],
  remainingFoundationQuestions: [
    {
      questionKey: 'foundation_v1_personal_values_02',
      text: 'When do you feel most understood?',
      domain: 'personal_values',
    },
  ],
};

test('Gemini client sends structured Interactions API request and reports usage', async () => {
  let capturedUrl = '';
  let capturedInit: RequestInit | undefined;
  const clockValues = [1_000, 1_240];
  const client = new GeminiInteractionsClient({
    apiKey: 'test-api-key',
    model: 'gemini-3.5-flash',
    now: () => clockValues.shift() ?? 1_240,
    fetcher: async (input, init) => {
      capturedUrl = String(input);
      capturedInit = init;
      return new Response(
        JSON.stringify({
          output_text: JSON.stringify({ feedback_text: 'A short response.' }),
          usage: {
            prompt_tokens: 18,
            completion_tokens: 7,
            total_tokens: 25,
          },
        }),
        { status: 200 },
      );
    },
  });

  const result = await client.generateStructured({
    prompt: 'Return a short response.',
    schema: {
      type: 'object',
      properties: { feedback_text: { type: 'string' } },
      required: ['feedback_text'],
      additionalProperties: false,
    },
  });

  assert.equal(
    capturedUrl,
    'https://generativelanguage.googleapis.com/v1/interactions',
  );
  assert.equal(
    new Headers(capturedInit?.headers).get('x-goog-api-key'),
    'test-api-key',
  );
  const body = JSON.parse(String(capturedInit?.body));
  assert.equal(body.model, 'models/gemini-3.5-flash');
  assert.equal(body.response_format.mime_type, 'application/json');
  assert.equal(body.response_format.schema.additionalProperties, false);
  assert.deepEqual(result.value, { feedback_text: 'A short response.' });
  assert.deepEqual(result.usage, {
    inputTokenCount: 18,
    outputTokenCount: 7,
    latencyMs: 240,
  });
});

test('Gemini client reads v1beta2 model output steps', async () => {
  const client = new GeminiInteractionsClient({
    apiKey: 'test-api-key',
    fetcher: async () => new Response(
      JSON.stringify({
        steps: [
          {
            type: 'model_output',
            content: [
              { type: 'text', text: '{"feedback_text":"Step output"}' },
            ],
          },
        ],
        usage: { prompt_tokens: 4, completion_tokens: 2 },
      }),
    ),
  });

  const result = await client.generateStructured({
    prompt: 'Return feedback.',
    schema: { type: 'object' },
  });

  assert.deepEqual(result.value, { feedback_text: 'Step output' });
});

test('Gemini client classifies rate limits as retryable', async () => {
  const clockValues = [1_000, 1_275];
  const client = new GeminiInteractionsClient({
    apiKey: 'test-api-key',
    now: () => clockValues.shift() ?? 1_275,
    fetcher: async () => new Response(
      JSON.stringify({
        error: {
          status: 'RESOURCE_EXHAUSTED',
          message: 'Quota exceeded',
          details: [
            {
              '@type': 'type.googleapis.com/google.rpc.RetryInfo',
              retryDelay: '45.25s',
            },
          ],
        },
      }),
      {
        status: 429,
        headers: { 'retry-after': '30' },
      },
    ),
  });

  await assert.rejects(
    () => client.generateStructured({
      prompt: 'Return feedback.',
      schema: { type: 'object' },
    }),
    (error: unknown) => {
      assert.ok(error instanceof GeminiProviderError);
      assert.equal(error.code, 'gemini_rate_limited');
      assert.equal(error.retryable, true);
      assert.equal(error.status, 429);
      assert.equal(error.providerStatus, 'RESOURCE_EXHAUSTED');
      assert.equal(error.retryAfterMs, 45_250);
      assert.equal(error.latencyMs, 275);
      return true;
    },
  );
});

test('Gemini client defaults to the lightweight stable model resource', async () => {
  let capturedBody = '';
  const client = new GeminiInteractionsClient({
    apiKey: 'test-api-key',
    fetcher: async (_input, init) => {
      capturedBody = String(init?.body);
      return new Response(JSON.stringify({
        output_text: '{"feedback_text":"ok"}',
      }));
    },
  });

  await client.generateStructured({
    prompt: 'Return feedback.',
    schema: { type: 'object' },
  });

  assert.equal(
    JSON.parse(capturedBody).model,
    'models/gemini-2.5-flash-lite',
  );
});

test('Gemini client preserves an explicit model resource name', async () => {
  let capturedBody = '';
  const client = new GeminiInteractionsClient({
    apiKey: 'test-api-key',
    model: 'models/gemini-2.5-flash',
    fetcher: async (_input, init) => {
      capturedBody = String(init?.body);
      return new Response(JSON.stringify({
        output_text: '{"feedback_text":"ok"}',
      }));
    },
  });

  await client.generateStructured({
    prompt: 'Return feedback.',
    schema: { type: 'object' },
  });

  assert.equal(JSON.parse(capturedBody).model, 'models/gemini-2.5-flash');
});

test('Gemini client classifies invalid requests as terminal', async () => {
  const client = new GeminiInteractionsClient({
    apiKey: 'test-api-key',
    fetcher: async () => new Response(
      JSON.stringify({ error: { message: 'Malformed schema' } }),
      { status: 400 },
    ),
  });

  await assert.rejects(
    () => client.generateStructured({
      prompt: 'Return feedback.',
      schema: { type: 'object' },
    }),
    (error: unknown) => {
      assert.ok(error instanceof GeminiProviderError);
      assert.equal(error.code, 'gemini_invalid_request');
      assert.equal(error.retryable, false);
      return true;
    },
  );
});

test('Gemini client classifies provider failures as retryable', async () => {
  const client = new GeminiInteractionsClient({
    apiKey: 'test-api-key',
    fetcher: async () => new Response(null, { status: 503 }),
  });

  await assert.rejects(
    () => client.generateStructured({
      prompt: 'Return feedback.',
      schema: { type: 'object' },
    }),
    (error: unknown) => {
      assert.ok(error instanceof GeminiProviderError);
      assert.equal(error.code, 'gemini_provider_unavailable');
      assert.equal(error.retryable, true);
      return true;
    },
  );
});

test('Gemini client classifies request aborts as retryable timeouts', async () => {
  const client = new GeminiInteractionsClient({
    apiKey: 'test-api-key',
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
      prompt: 'Return feedback.',
      schema: { type: 'object' },
    }),
    (error: unknown) => {
      assert.ok(error instanceof GeminiProviderError);
      assert.equal(error.code, 'gemini_timeout');
      assert.equal(error.retryable, true);
      return true;
    },
  );
});

test('Gemini client rejects malformed structured output', async () => {
  const client = new GeminiInteractionsClient({
    apiKey: 'test-api-key',
    fetcher: async () => new Response(
      JSON.stringify({ output_text: 'not-json' }),
    ),
  });

  await assert.rejects(
    () => client.generateStructured({
      prompt: 'Return feedback.',
      schema: { type: 'object' },
    }),
    (error: unknown) => {
      assert.ok(error instanceof GeminiOutputError);
      assert.equal(error.code, 'gemini_invalid_output');
      assert.equal(error.retryable, false);
      return true;
    },
  );
});

test('Gemini model maps memory output without real user identifiers', async () => {
  let capturedPrompt = '';
  const model = new GeminiLearningModel({
    generateStructured: async ({ prompt }) => {
      capturedPrompt = prompt;
      return {
        value: {
          memories: [
            {
              memory_key: 'partner_a_quiet_time',
              scope: 'personal',
              subject_participant_key: 'partner_a',
              kind: 'personal_value',
              statement: 'Partner A values quiet time together.',
              confidence: 0.82,
              evidence_answer_ids: ['answer-a'],
            },
          ],
        },
        usage: {
          inputTokenCount: 30,
          outputTokenCount: 20,
          latencyMs: 150,
        },
      };
    },
  });

  const result = await model.extractMemoryCandidates(context);

  assert.equal(capturedPrompt.includes('partner_a'), true);
  assert.equal(capturedPrompt.includes('real-user-id'), false);
  assert.deepEqual(result.value, [
    {
      memoryKey: 'partner_a_quiet_time',
      scope: 'personal',
      subjectParticipantKey: 'partner_a',
      kind: 'personal_value',
      statement: 'Partner A values quiet time together.',
      confidence: 0.82,
      evidenceAnswerIds: ['answer-a'],
    },
  ]);
  assert.equal(result.usage.inputTokenCount, 30);
});

test('Gemini model maps feedback and question outputs', async () => {
  const outputs = [
    {
      feedback_text: 'Your different preferences can complement each other.',
    },
    {
      question_key: 'foundation_v1_personal_values_02',
      rationale: 'It explores how each partner feels understood.',
    },
    {
      question_key: 'personalized_shared_weekend_ab12cd34',
      question_text: 'What would make this weekend feel balanced for both?',
      category: 'personalized',
      mood: null,
      rationale: 'Their preferred ways of spending time differ.',
    },
  ];
  const model = new GeminiLearningModel({
    generateStructured: async () => ({
      value: outputs.shift(),
      usage: {
        inputTokenCount: null,
        outputTokenCount: null,
        latencyMs: 10,
      },
    }),
  });

  const feedback = await model.generateCoupleFeedback(context);
  const ranking = await model.rankFoundationQuestions(
    context,
    context.remainingFoundationQuestions,
  );
  const personalized = await model.generatePersonalizedQuestion(context);

  assert.equal(
    feedback.value.text,
    'Your different preferences can complement each other.',
  );
  assert.equal(
    ranking.value.questionKey,
    'foundation_v1_personal_values_02',
  );
  assert.equal(
    personalized.value.questionKey,
    'personalized_shared_weekend_ab12cd34',
  );
  assert.equal(personalized.value.mood, null);
});

test('Gemini model rejects structurally invalid values after JSON decoding', async () => {
  const model = new GeminiLearningModel({
    generateStructured: async () => ({
      value: { feedback_text: 42 },
      usage: {
        inputTokenCount: 1,
        outputTokenCount: 1,
        latencyMs: 1,
      },
    }),
  });

  await assert.rejects(
    () => model.generateCoupleFeedback(context),
    (error: unknown) => {
      assert.ok(error instanceof GeminiOutputError);
      assert.equal(error.code, 'gemini_invalid_output');
      return true;
    },
  );
});
