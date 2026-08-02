import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createCandidateModelEvaluationPlan,
} from '../eval/candidate-model-eval-config.ts';

test('candidate evaluation can prepare Cloudflare models independently', () => {
  const plan = createCandidateModelEvaluationPlan({
    AI_CANDIDATE_EVAL_PROVIDERS: 'cloudflare',
    CLOUDFLARE_ACCOUNT_ID: '0123456789abcdef0123456789abcdef',
    CLOUDFLARE_WORKERS_AI_API_TOKEN: 'test-token',
  });

  assert.equal(plan.runs, 1);
  assert.equal(plan.suite, 'smoke');
  assert.equal(plan.outputPath, null);
  assert.deepEqual(
    plan.models.map((item) => item.model),
    [
      '@cf/qwen/qwen3-30b-a3b-fp8',
      '@cf/zai-org/glm-4.7-flash',
      '@cf/google/gemma-4-26b-a4b-it',
      '@cf/mistralai/mistral-small-3.1-24b-instruct',
    ],
  );
  assert.ok(plan.models.every((item) => item.provider === 'cloudflare'));
  assert.ok(plan.models.every((item) => item.caseDelayMs === 0));
});

test('candidate evaluation prepares rate-limited Groq models', () => {
  const plan = createCandidateModelEvaluationPlan({
    AI_CANDIDATE_EVAL_PROVIDERS: 'groq',
    GROQ_API_KEY: 'test-api-key',
    AI_MODEL_EVAL_RUNS: '2',
    AI_CANDIDATE_EVAL_SUITE: 'full',
    AI_CANDIDATE_EVAL_OUTPUT: 'D:\\result.json',
  });

  assert.equal(plan.runs, 2);
  assert.equal(plan.suite, 'full');
  assert.equal(plan.outputPath, 'D:\\result.json');
  assert.deepEqual(
    plan.models.map((item) => item.model),
    ['openai/gpt-oss-120b', 'openai/gpt-oss-20b'],
  );
  assert.ok(plan.models.every((item) => item.provider === 'groq'));
  assert.ok(plan.models.every((item) => item.caseDelayMs === 15_000));
  assert.deepEqual(plan.models[0]?.configuration, {
    reasoningEffort: 'low',
    structuredOutput: 'strict_json_schema',
  });
});

test('candidate evaluation accepts explicit model and pacing overrides', () => {
  const plan = createCandidateModelEvaluationPlan({
    AI_CANDIDATE_EVAL_PROVIDERS: 'groq',
    GROQ_API_KEY: 'test-api-key',
    GROQ_EVAL_MODELS: 'openai/gpt-oss-20b, openai/gpt-oss-20b',
    GROQ_EVAL_REASONING_EFFORT: 'medium',
    GROQ_EVAL_CASE_DELAY_MS: '9000',
  });

  assert.equal(plan.models.length, 1);
  assert.equal(plan.models[0]?.model, 'openai/gpt-oss-20b');
  assert.equal(plan.models[0]?.caseDelayMs, 9_000);
  assert.equal(plan.models[0]?.configuration?.reasoningEffort, 'medium');
});

test('candidate evaluation prepares OpenAI Responses models independently', () => {
  const plan = createCandidateModelEvaluationPlan({
    AI_CANDIDATE_EVAL_PROVIDERS: 'openai',
    OPENAI_API_KEY: 'test-api-key',
  });

  assert.deepEqual(
    plan.models.map((item) => item.model),
    ['gpt-5-nano'],
  );
  assert.ok(plan.models.every((item) => item.provider === 'openai'));
  assert.ok(plan.models.every((item) => item.caseDelayMs === 0));
  assert.deepEqual(plan.models[0]?.configuration, {
    reasoningEffort: 'minimal',
    structuredOutput: 'responses_json_schema',
  });
});

test('candidate evaluation chooses OpenAI reasoning defaults per model family', () => {
  const plan = createCandidateModelEvaluationPlan({
    AI_CANDIDATE_EVAL_PROVIDERS: 'openai',
    OPENAI_API_KEY: 'test-api-key',
    OPENAI_EVAL_MODELS: 'gpt-5-nano,gpt-5.4-nano,gpt-5.6-luna',
  });

  assert.deepEqual(
    plan.models.map((item) => ({
      model: item.model,
      reasoningEffort: item.configuration?.reasoningEffort,
    })),
    [
      { model: 'gpt-5-nano', reasoningEffort: 'minimal' },
      { model: 'gpt-5.4-nano', reasoningEffort: 'none' },
      { model: 'gpt-5.6-luna', reasoningEffort: 'none' },
    ],
  );
});

test('candidate evaluation accepts OpenAI model and reasoning overrides', () => {
  const plan = createCandidateModelEvaluationPlan({
    AI_CANDIDATE_EVAL_PROVIDERS: 'openai',
    OPENAI_API_KEY: 'test-api-key',
    OPENAI_EVAL_MODELS: 'gpt-5.6-luna, gpt-5.6-luna',
    OPENAI_EVAL_REASONING_EFFORT: 'low',
    OPENAI_EVAL_CASE_DELAY_MS: '250',
  });

  assert.equal(plan.models.length, 1);
  assert.equal(plan.models[0]?.model, 'gpt-5.6-luna');
  assert.equal(plan.models[0]?.caseDelayMs, 250);
  assert.equal(plan.models[0]?.configuration?.reasoningEffort, 'low');
});

test('candidate evaluation accepts minimal OpenAI reasoning', () => {
  const plan = createCandidateModelEvaluationPlan({
    AI_CANDIDATE_EVAL_PROVIDERS: 'openai',
    OPENAI_API_KEY: 'test-api-key',
    OPENAI_EVAL_MODELS: 'gpt-5-nano',
    OPENAI_EVAL_REASONING_EFFORT: 'minimal',
  });

  assert.equal(plan.models[0]?.configuration?.reasoningEffort, 'minimal');
});

test('candidate evaluation requires credentials only for selected providers', () => {
  assert.throws(
    () => createCandidateModelEvaluationPlan({
      AI_CANDIDATE_EVAL_PROVIDERS: 'groq',
    }),
    /GROQ_API_KEY is required/,
  );
  assert.throws(
    () => createCandidateModelEvaluationPlan({
      AI_CANDIDATE_EVAL_PROVIDERS: 'cloudflare',
    }),
    /CLOUDFLARE_ACCOUNT_ID is required/,
  );
  assert.throws(
    () => createCandidateModelEvaluationPlan({
      AI_CANDIDATE_EVAL_PROVIDERS: 'openai',
    }),
    /OPENAI_API_KEY is required/,
  );
  assert.throws(
    () => createCandidateModelEvaluationPlan({
      AI_CANDIDATE_EVAL_PROVIDERS: 'unknown',
    }),
    /unsupported provider/,
  );
});
