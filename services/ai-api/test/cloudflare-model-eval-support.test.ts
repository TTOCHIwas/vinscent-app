import assert from 'node:assert/strict';
import test from 'node:test';

import {
  LearningModelError,
} from '../src/application/learning-model-port.ts';
import {
  createCompletedEvaluationContext,
  createFoundationEvaluationContext,
  runEvaluationCase,
} from '../eval/cloudflare-model-eval-support.ts';

test('foundation evaluation uses an incomplete non-personalized context', () => {
  const context = createFoundationEvaluationContext();

  assert.equal(context.foundationProgress.completedCount, 12);
  assert.equal(context.foundationProgress.totalCount, 24);
  assert.equal(context.foundationProgress.personalizationEnabled, false);
  assert.ok(context.remainingFoundationQuestions.length > 0);
});

test('completed evaluation context enables personalization after 24 answers', () => {
  const context = createCompletedEvaluationContext();

  assert.equal(context.foundationProgress.completedCount, 24);
  assert.equal(context.foundationProgress.totalCount, 24);
  assert.equal(context.foundationProgress.personalizationEnabled, true);
});

test('evaluation preserves model diagnostics and usage on generation failure', async () => {
  const error = new LearningModelError({
    code: 'model_invalid_output',
    retryable: false,
    diagnosticDetail: 'feedback.feedback_text.invalid',
    usage: {
      inputTokenCount: 41,
      outputTokenCount: 9,
      latencyMs: 275,
    },
  });

  const result = await runEvaluationCase({
    name: 'couple_feedback',
    execute: async () => {
      throw error;
    },
    validate: () => {
      throw new Error('validation must not run');
    },
  });

  assert.deepEqual(result, {
    name: 'couple_feedback',
    status: 'failed',
    failurePhase: 'generation',
    inputTokenCount: 41,
    outputTokenCount: 9,
    latencyMs: 275,
    output: null,
    error: {
      name: 'LearningModelError',
      code: 'model_invalid_output',
      message: 'model_invalid_output',
      diagnosticDetail: 'feedback.feedback_text.invalid',
      retryable: false,
      providerHttpStatus: null,
      providerErrorStatus: null,
    },
  });
});

test('evaluation preserves synthetic output and usage on validation failure', async () => {
  const output = {
    text: '서로 다른 답을 하나의 공통 기억으로 합쳤어',
  };

  const result = await runEvaluationCase({
    name: 'memory_extraction',
    execute: async () => ({
      value: output,
      usage: {
        inputTokenCount: 52,
        outputTokenCount: 11,
        latencyMs: 310,
      },
    }),
    validate: () => {
      throw new Error('couple memory is not supported by both answers');
    },
  });

  assert.deepEqual(result, {
    name: 'memory_extraction',
    status: 'failed',
    failurePhase: 'validation',
    inputTokenCount: 52,
    outputTokenCount: 11,
    latencyMs: 310,
    output,
    error: {
      name: 'Error',
      code: null,
      message: 'couple memory is not supported by both answers',
      diagnosticDetail: null,
      retryable: null,
      providerHttpStatus: null,
      providerErrorStatus: null,
    },
  });
});
