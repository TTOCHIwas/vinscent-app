import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  LearningModelPort,
} from '../src/application/learning-model-port.ts';
import type {
  ModelEvaluationCase,
} from '../eval/cloudflare-model-eval-case.ts';
import {
  runModelEvaluation,
} from '../eval/model-evaluation-runner.ts';

const evaluationCase: ModelEvaluationCase = {
  name: 'shared_case',
  task: 'couple_feedback',
  scenario: '같은 사례를 공급자별로 실행',
  source: 'representative_boundary',
  expectation: '공급자와 모델별 결과를 분리해 기록해',
  run: (model) => model.generateCoupleFeedback({} as never),
  validate: (value) => {
    const text = (value as { text?: unknown }).text;
    if (text !== '통과') {
      throw new Error('unexpected output');
    }
  },
};

test('model evaluation runner compares providers with the same cases', async () => {
  const execution = await runModelEvaluation({
    models: [
      modelSpec('cloudflare', 'small-model', '통과'),
      modelSpec('google', 'gemini-model', '실패'),
    ],
    cases: [evaluationCase],
    runs: 1,
    now: () => new Date('2026-08-01T00:00:00.000Z'),
  });

  assert.equal(execution.hasFailure, true);
  assert.equal(execution.report.generatedAt, '2026-08-01T00:00:00.000Z');
  assert.equal(execution.report.distinctScenarioCount, 1);
  assert.deepEqual(
    execution.report.report.map((result) => ({
      provider: result.provider,
      model: result.model,
      passed: result.passed,
    })),
    [
      { provider: 'cloudflare', model: 'small-model', passed: 1 },
      { provider: 'google', model: 'gemini-model', passed: 0 },
    ],
  );
  assert.equal(execution.report.report[1]?.results[0]?.failurePhase, 'validation');
});

test('model evaluation runner waits before each case when a model requests pacing', async () => {
  const delays: number[] = [];
  const execution = await runModelEvaluation({
    models: [{
      ...modelSpec('google', 'paced-model', '통과'),
      caseDelayMs: 4_200,
    }],
    cases: [
      evaluationCase,
      { ...evaluationCase, name: 'second_shared_case' },
    ],
    runs: 1,
    wait: async (delayMs) => {
      delays.push(delayMs);
    },
  });

  assert.equal(execution.hasFailure, false);
  assert.deepEqual(delays, [4_200, 4_200]);
});

test('model evaluation runner rejects an invalid case delay', async () => {
  await assert.rejects(
    runModelEvaluation({
      models: [{
        ...modelSpec('google', 'invalid-delay-model', '통과'),
        caseDelayMs: -1,
      }],
      cases: [evaluationCase],
      runs: 1,
    }),
    /case delay must be a non-negative integer/i,
  );
});

function modelSpec(
  provider: string,
  model: string,
  text: string,
): {
  provider: string;
  model: string;
  createModel(): LearningModelPort;
} {
  return {
    provider,
    model,
    createModel: () => ({
      async generateCoupleFeedback() {
        return {
          value: { text },
          usage: {
            inputTokenCount: 10,
            outputTokenCount: 5,
            latencyMs: 20,
          },
        };
      },
    } as LearningModelPort),
  };
}
