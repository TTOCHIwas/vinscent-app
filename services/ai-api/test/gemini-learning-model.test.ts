import assert from 'node:assert/strict';
import test from 'node:test';

import {
  GeminiStructuredGenerationClient,
  GeminiOutputError,
  GeminiProviderError,
} from '../src/infrastructure/gemini-structured-generation-client.ts';
import { GeminiLearningModel } from '../src/infrastructure/gemini-learning-model.ts';
import type {
  AnonymizedCompletedQuestionContext,
  GeneralQuestionContext,
} from '../src/domain/learning-contract.ts';

const context: AnonymizedCompletedQuestionContext = {
  question: {
    dailyQuestionId: 'daily-question-1',
    questionId: 'question-1',
    text: 'What kind of time together feels most meaningful?',
    domain: 'personal_values',
    depth: 'light',
    promptAngle: 'preference',
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
  foundationProgress: {
    completedCount: 1,
    totalCount: 24,
    personalizationEnabled: false,
    domainProgress: {
      personal_values: { completedCount: 1, totalCount: 4 },
      emotional_support: { completedCount: 0, totalCount: 4 },
      communication_repair: { completedCount: 0, totalCount: 4 },
      daily_life: { completedCount: 0, totalCount: 4 },
      relationship_strength: { completedCount: 0, totalCount: 4 },
      future_boundaries: { completedCount: 0, totalCount: 4 },
    },
  },
  confirmedMemories: [],
  memoryCandidates: [],
  recentFoundationQuestions: [],
  recentCompletedQuestions: [],
  remainingFoundationQuestions: [
    {
      questionKey: 'foundation_v1_personal_values_02',
      text: 'When do you feel most understood?',
      domain: 'personal_values',
      depth: 'exploratory',
      promptAngle: 'lived_experience',
    },
  ],
};

const generalQuestionContext: GeneralQuestionContext = {
  foundationProgress: {
    completedCount: 24,
    totalCount: 24,
  },
  recentQuestions: [
    {
      questionKey: 'foundation_v1_daily_life_04',
      text: 'What part of an ordinary day do you want to share more often?',
      category: 'daily_life',
      mood: 'calm',
      domain: 'daily_life',
    },
  ],
};

test('Gemini client sends structured generateContent request and reports usage', async () => {
  let capturedUrl = '';
  let capturedInit: RequestInit | undefined;
  const clockValues = [1_000, 1_240];
  const client = new GeminiStructuredGenerationClient({
    apiKey: 'test-api-key',
    model: 'gemini-3.5-flash',
    now: () => clockValues.shift() ?? 1_240,
    fetcher: async (input, init) => {
      capturedUrl = String(input);
      capturedInit = init;
      return new Response(
        JSON.stringify({
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      feedback_text: 'A short response.',
                    }),
                  },
                ],
              },
            },
          ],
          usageMetadata: {
            promptTokenCount: 18,
            candidatesTokenCount: 7,
            totalTokenCount: 25,
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
    'https://generativelanguage.googleapis.com/v1beta/models/'
      + 'gemini-3.5-flash:generateContent',
  );
  assert.equal(
    new Headers(capturedInit?.headers).get('x-goog-api-key'),
    'test-api-key',
  );
  const body = JSON.parse(String(capturedInit?.body));
  assert.equal(body.contents[0].parts[0].text, 'Return a short response.');
  assert.equal(
    Object.hasOwn(body.generationConfig, 'temperature'),
    false,
  );
  assert.equal(body.generationConfig.responseMimeType, 'application/json');
  assert.equal(
    body.generationConfig.responseJsonSchema.additionalProperties,
    false,
  );
  assert.deepEqual(result.value, { feedback_text: 'A short response.' });
  assert.deepEqual(result.usage, {
    inputTokenCount: 18,
    outputTokenCount: 7,
    latencyMs: 240,
  });
});

test('Gemini client reads generateContent candidate parts', async () => {
  const client = new GeminiStructuredGenerationClient({
    apiKey: 'test-api-key',
    fetcher: async () => new Response(
      JSON.stringify({
        candidates: [
          {
            content: {
              parts: [{ text: '{"feedback_text":"Step output"}' }],
            },
          },
        ],
        usageMetadata: { promptTokenCount: 4, candidatesTokenCount: 2 },
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
  const client = new GeminiStructuredGenerationClient({
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

test('Gemini client defaults to the lightweight stable model endpoint', async () => {
  let capturedUrl = '';
  const client = new GeminiStructuredGenerationClient({
    apiKey: 'test-api-key',
    fetcher: async (input) => {
      capturedUrl = String(input);
      return new Response(JSON.stringify({
        candidates: [{
          content: { parts: [{ text: '{"feedback_text":"ok"}' }] },
        }],
      }));
    },
  });

  await client.generateStructured({
    prompt: 'Return feedback.',
    schema: { type: 'object' },
  });

  assert.equal(
    capturedUrl,
    'https://generativelanguage.googleapis.com/v1beta/models/'
      + 'gemini-3.1-flash-lite:generateContent',
  );
});

test('Gemini client accepts an explicit model resource name', async () => {
  let capturedUrl = '';
  const client = new GeminiStructuredGenerationClient({
    apiKey: 'test-api-key',
    model: 'models/gemini-2.5-flash',
    fetcher: async (input) => {
      capturedUrl = String(input);
      return new Response(JSON.stringify({
        candidates: [{
          content: { parts: [{ text: '{"feedback_text":"ok"}' }] },
        }],
      }));
    },
  });

  await client.generateStructured({
    prompt: 'Return feedback.',
    schema: { type: 'object' },
  });

  assert.equal(
    capturedUrl,
    'https://generativelanguage.googleapis.com/v1beta/models/'
      + 'gemini-2.5-flash:generateContent',
  );
});

test('Gemini client classifies invalid requests as terminal', async () => {
  const client = new GeminiStructuredGenerationClient({
    apiKey: 'test-api-key',
    fetcher: async () => new Response(
      JSON.stringify({
        error: {
          status: 'INVALID_ARGUMENT',
          message: 'Malformed\nresponse schema for key AIza0123456789abcdef',
        },
      }),
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
      assert.equal(error.providerStatus, 'INVALID_ARGUMENT');
      assert.equal(
        error.providerErrorDetail,
        'Malformed response schema for key [REDACTED]',
      );
      return true;
    },
  );
});

test('Gemini client classifies provider failures as retryable', async () => {
  const client = new GeminiStructuredGenerationClient({
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
  const client = new GeminiStructuredGenerationClient({
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
  const client = new GeminiStructuredGenerationClient({
    apiKey: 'test-api-key',
    fetcher: async () => new Response(
      JSON.stringify({
        candidates: [{ content: { parts: [{ text: 'not-json' }] } }],
      }),
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
              learning_domain: 'personal_values',
              evidence_type: 'explicit',
              sensitive_category: 'none',
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
      domain: 'personal_values',
      evidenceType: 'explicit',
      sensitiveCategory: 'none',
      statement: 'Partner A values quiet time together.',
      confidence: 0.82,
      evidenceAnswerIds: ['answer-a'],
    },
  ]);
  assert.equal(result.usage.inputTokenCount, 30);
});

test('memory extraction uses a typed provider schema and a complete prompt contract', async () => {
  let capturedPrompt = '';
  let capturedSchema: unknown;
  const model = new GeminiLearningModel({
    generateStructured: async ({ prompt, schema }) => {
      capturedPrompt = prompt;
      capturedSchema = schema;
      return {
        value: {
          memories: [
            {
              memory_key: 'shared_quiet_time',
              scope: 'couple',
              subject_participant_key: 'couple',
              kind: 'shared_preference',
              learning_domain: 'daily_life',
              evidence_type: 'explicit',
              sensitive_category: 'none',
              statement: 'Both partners value quiet time together.',
              confidence: 0.84,
              evidence_answer_ids: ['answer-a', 'answer-b'],
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
  assert.deepEqual(capturedSchema, {
    type: 'object',
    properties: {
      memories: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            memory_key: { type: 'string' },
            scope: { type: 'string' },
            subject_participant_key: { type: 'string' },
            kind: { type: 'string' },
            learning_domain: { type: 'string' },
            evidence_type: { type: 'string' },
            sensitive_category: { type: 'string' },
            statement: { type: 'string' },
            confidence: { type: 'number' },
            evidence_answer_ids: {
              type: 'array',
              items: { type: 'string' },
            },
          },
          required: [
            'memory_key',
            'scope',
            'subject_participant_key',
            'kind',
            'learning_domain',
            'evidence_type',
            'sensitive_category',
            'statement',
            'confidence',
            'evidence_answer_ids',
          ],
        },
      },
    },
    required: ['memories'],
    additionalProperties: false,
  });
  for (const field of [
    'memory_key',
    'scope',
    'subject_participant_key',
    'kind',
    'learning_domain',
    'evidence_type',
    'sensitive_category',
    'statement',
    'confidence',
    'evidence_answer_ids',
  ]) {
    assert.equal(capturedPrompt.includes(field), true, `${field} is documented`);
  }
  assert.equal(result.value[0]?.scope, 'couple');
  assert.equal(result.value[0]?.subjectParticipantKey, null);
});

test('memory extraction reports the invalid field without exposing its value', async () => {
  const model = new GeminiLearningModel({
    generateStructured: async () => ({
      value: {
        memories: [
          {
            memory_key: 'partner_a_quiet_time',
            scope: 'personal',
            subject_participant_key: 'partner_a',
            kind: 'personal_value',
            learning_domain: 'personal_values',
            evidence_type: 'explicit',
            sensitive_category: 'none',
            statement: 'Partner A values quiet time together.',
            confidence: 'private-invalid-value',
            evidence_answer_ids: ['answer-a'],
          },
        ],
      },
      usage: {
        inputTokenCount: 30,
        outputTokenCount: 20,
        latencyMs: 150,
      },
    }),
  });

  await assert.rejects(
    () => model.extractMemoryCandidates(context),
    (error: unknown) => {
      assert.ok(error instanceof GeminiOutputError);
      const validationDetail = (
        error as GeminiOutputError & { validationDetail?: string }
      ).validationDetail;
      assert.equal(validationDetail, 'memory.confidence.invalid');
      assert.equal(validationDetail?.includes('private-invalid-value'), false);
      return true;
    },
  );
});

test('memory extraction rejects more than twelve model candidates', async () => {
  const model = new GeminiLearningModel({
    generateStructured: async () => ({
      value: {
        memories: Array.from({ length: 13 }, (_, index) => ({
          memory_key: `partner_a_preference_${index}`,
          scope: 'personal',
          subject_participant_key: 'partner_a',
          kind: 'personal_value',
          learning_domain: 'personal_values',
          evidence_type: 'explicit',
          sensitive_category: 'none',
          statement: `Partner A preference ${index}.`,
          confidence: 0.8,
          evidence_answer_ids: ['answer-a'],
        })),
      },
      usage: {
        inputTokenCount: 30,
        outputTokenCount: 300,
        latencyMs: 150,
      },
    }),
  });

  await assert.rejects(
    () => model.extractMemoryCandidates(context),
    (error: unknown) => error instanceof GeminiOutputError,
  );
});

test('foundation ranking receives metadata but not answers or memories', async () => {
  let capturedPrompt = '';
  const model = new GeminiLearningModel({
    generateStructured: async ({ prompt }) => {
      capturedPrompt = prompt;
      return {
        value: {
          question_key: 'foundation_v1_personal_values_02',
          rationale: '영역 균형과 깊이를 보완한다.',
        },
        usage: {
          inputTokenCount: null,
          outputTokenCount: null,
          latencyMs: 1,
        },
      };
    },
  });

  await model.rankFoundationQuestions(
    context,
    context.remainingFoundationQuestions,
  );

  assert.equal(capturedPrompt.includes('Quiet time at home matters to me.'), false);
  assert.equal(capturedPrompt.includes('confirmed_memories'), false);
  assert.equal(capturedPrompt.includes('domain_progress'), true);
  assert.equal(capturedPrompt.includes('question_depth'), true);
});

test('feedback prompt requests a shared character reaction instead of an answer summary', async () => {
  const prompts: string[] = [];
  const model = new GeminiLearningModel({
    generateStructured: async ({ prompt }) => {
      prompts.push(prompt);
      return {
        value: { feedback_text: '소중한 걸 고르는 데도 시간이 조금 필요한가 봐!' },
        usage: {
          inputTokenCount: null,
          outputTokenCount: null,
          latencyMs: 1,
        },
      };
    },
  });

  await model.generateCoupleFeedback(context);
  await model.generateCoupleFeedback(context, {
    rejectedText: '너는 시간을 소중하게 생각하는데 상대방은 아직 잘 모르겠나 봐',
  });
  const capturedPrompt = prompts[0] ?? '';
  const retryPrompt = prompts[1] ?? '';

  assert.equal(
    capturedPrompt.includes('The same reaction is shown unchanged to both participants.'),
    true,
  );
  assert.equal(
    capturedPrompt.includes("React as the couple's small app character"),
    true,
  );
  assert.equal(
    capturedPrompt.includes('Do not summarize, list, quote back, or merely label'),
    true,
  );
  assert.equal(
    capturedPrompt.includes('a small connection, gentle wordplay, a concrete scene, or a warm observation'),
    true,
  );
  assert.equal(capturedPrompt.includes('몰라'), true);
  assert.equal(capturedPrompt.includes('Never identify who wrote either answer'), true);
  assert.equal(capturedPrompt.includes('Do not use a period'), true);
  assert.equal(
    capturedPrompt.includes('End with no punctuation, one "!", one "?", or exactly "..."'),
    true,
  );
  assert.equal(
    capturedPrompt.includes('Do not erase, avoid, or force a positive spin on negative answers'),
    true,
  );
  assert.equal(
    capturedPrompt.includes('오늘은 둘의 하루가 평소보다 조금 무거운 날인가 봐...'),
    true,
  );
  assert.equal(
    capturedPrompt.includes('소중한 걸 고르는 데도 시간이 조금 필요한가 봐!'),
    true,
  );
  assert.equal(capturedPrompt.includes('"rejected_feedback":'), false);
  assert.equal(retryPrompt.includes('"rejected_feedback":'), true);
  assert.equal(
    retryPrompt.includes('너는 시간을 소중하게 생각하는데 상대방은 아직 잘 모르겠나 봐'),
    true,
  );
});

test('feedback uses profile and recent six answers only after personalization opens', async () => {
  const prompts: string[] = [];
  const model = new GeminiLearningModel({
    generateStructured: async ({ prompt }) => {
      prompts.push(prompt);
      return {
        value: { feedback_text: '쉬는 방식은 달라도 함께 보내는 시간은 둘 다 소중하게 여기네.' },
        usage: {
          inputTokenCount: null,
          outputTokenCount: null,
          latencyMs: 1,
        },
      };
    },
  });
  const personalizedContext: AnonymizedCompletedQuestionContext = {
    ...context,
    foundationProgress: {
      ...context.foundationProgress,
      completedCount: 24,
      personalizationEnabled: true,
    },
    confirmedMemories: [
      {
        memoryKey: 'shared_walks',
        scope: 'couple',
        subjectParticipantKey: null,
        kind: 'shared_preference',
        domain: 'daily_life',
        evidenceType: 'explicit',
        statement: '둘 다 산책을 좋아한다.',
        confidence: 0.9,
      },
    ],
    recentCompletedQuestions: [
      {
        question: {
          dailyQuestionId: 'recent-question-1',
          text: '지난 주말에는 뭘 했어?',
          domain: 'daily_life',
        },
        answers: [
          {
            answerId: 'recent-answer-a',
            participantKey: 'partner_a',
            text: '함께 공원을 걸었어.',
          },
          {
            answerId: 'recent-answer-b',
            participantKey: 'partner_b',
            text: '산책이 좋았어.',
          },
        ],
      },
    ],
  };

  await model.generateCoupleFeedback(context);
  await model.generateCoupleFeedback(personalizedContext);

  assert.equal(prompts[0]?.includes('둘 다 산책을 좋아한다.'), false);
  assert.equal(prompts[0]?.includes('함께 공원을 걸었어.'), false);
  assert.equal(prompts[1]?.includes('둘 다 산책을 좋아한다.'), true);
  assert.equal(prompts[1]?.includes('함께 공원을 걸었어.'), true);
});

test('general question prompt contains history metadata but no answer or memory', async () => {
  let prompt = '';
  const model = new GeminiLearningModel({
    generateStructured: async (request) => {
      prompt = request.prompt;
      return {
        value: {
          question_key: 'general_small_ritual_ab12cd34',
          question_text: '요즘 둘만의 작은 습관으로 만들고 싶은 건 뭐야?',
          category: 'daily_life',
          mood: 'warm',
          rationale: 'Recent questions have not covered shared rituals.',
        },
        usage: {
          inputTokenCount: 10,
          outputTokenCount: 5,
          latencyMs: 20,
        },
      };
    },
  });

  await model.generateGeneralQuestion(generalQuestionContext);

  assert.equal(prompt.includes('foundation_v1_daily_life_04'), true);
  assert.equal(prompt.includes('Quiet time at home matters to me.'), false);
  assert.equal(prompt.includes('confirmed_profile'), false);
  assert.equal(prompt.includes('current_answers'), false);
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
      question_key: 'general_small_ritual_ab12cd34',
      question_text: '요즘 둘만의 작은 습관으로 만들고 싶은 건 뭐야?',
      category: 'daily_life',
      mood: 'warm',
      rationale: 'Recent questions have not covered shared rituals.',
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
  const general = await model.generateGeneralQuestion(generalQuestionContext);
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
    general.value.questionKey,
    'general_small_ritual_ab12cd34',
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
