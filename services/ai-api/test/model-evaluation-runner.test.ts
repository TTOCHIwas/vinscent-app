import assert from 'node:assert/strict';
import test from 'node:test';

import {
  LearningModelError,
  type LearningModelResult,
  type LearningModelPort,
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

test('model evaluation runner records configuration and reports progress', async () => {
  const progress: Array<{
    modelIndex: number;
    caseIndex: number;
    status: string;
  }> = [];
  const execution = await runModelEvaluation({
    models: [{
      ...modelSpec('groq', 'openai/gpt-oss-20b', '통과'),
      configuration: {
        reasoningEffort: 'low',
        strictStructuredOutput: true,
      },
    }],
    cases: [evaluationCase],
    runs: 1,
    onCaseComplete: (item) => {
      progress.push({
        modelIndex: item.modelIndex,
        caseIndex: item.caseIndex,
        status: item.result.status,
      });
    },
  });

  assert.deepEqual(execution.report.report[0]?.configuration, {
    reasoningEffort: 'low',
    strictStructuredOutput: true,
  });
  assert.deepEqual(progress, [{
    modelIndex: 1,
    caseIndex: 1,
    status: 'passed',
  }]);
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

test('model evaluation keeps first-pass quality separate from operational recovery', async () => {
  let firstPassCount = 0;
  const recoverableCase: ModelEvaluationCase = {
    ...evaluationCase,
    name: 'recoverable_feedback',
    run: async () => {
      firstPassCount += 1;
      return modelResult('답변 주인을 드러낸 실패 문장', 1, 'stop');
    },
    recoverValidation: async (_model, rejectedOutput) => {
      assert.deepEqual(rejectedOutput, {
        text: '답변 주인을 드러낸 실패 문장',
      });
      return modelResult('통과', 2, 'stop');
    },
    validateForRecovery: evaluationCase.validate,
  };
  const execution = await runModelEvaluation({
    models: [modelSpec('groq', 'openai/gpt-oss-120b', 'unused')],
    cases: [recoverableCase],
    runs: 1,
  });

  const run = execution.report.report[0]!;
  const result = run.results[0]!;
  assert.equal(firstPassCount, 1);
  assert.equal(run.passed, 0);
  assert.equal(run.operationalPassed, 1);
  assert.equal(run.servedPassed, 1);
  assert.equal(run.recovered, 1);
  assert.equal(run.fallbackRecovered, 0);
  assert.equal(result.status, 'failed');
  assert.equal(result.operationalStatus, 'passed');
  assert.equal(result.servedStatus, 'passed');
  assert.equal(result.providerAttemptCount, 1);
  assert.equal(result.completionReason, 'stop');
  assert.equal(result.recovery?.status, 'passed');
  assert.equal(result.recovery?.providerAttemptCount, 2);
  assert.equal(result.fallback, null);
  assert.equal(run.inputTokenCount, 20);
  assert.equal(run.outputTokenCount, 10);
  assert.equal(run.latencyMs, 40);
  assert.equal(run.taskSummary.couple_feedback?.inputTokenCount, 20);
  assert.equal(run.taskSummary.couple_feedback?.outputTokenCount, 10);
  assert.equal(run.taskSummary.couple_feedback?.latencyMs, 40);
  assert.equal(execution.hasFailure, true);
  assert.equal(execution.hasOperationalFailure, false);
  assert.equal(execution.hasServedFailure, false);
});

test('model evaluation records a deterministic fallback without hiding model failures', async () => {
  const fallbackCase: ModelEvaluationCase = {
    ...evaluationCase,
    name: 'fallback_feedback',
    run: async () => modelResult('첫 번째 실패', 1, 'stop'),
    recoverValidation: async () =>
      modelResult('두 번째 실패', 1, 'stop'),
    validateForRecovery: evaluationCase.validate,
    resolveFallback: (_rejectedOutput, rejectionCode) => {
      assert.equal(rejectionCode, null);
      return {
        value: { text: '통과' },
        usage: {
          inputTokenCount: 0,
          outputTokenCount: 0,
          latencyMs: 0,
        },
      };
    },
  };
  const execution = await runModelEvaluation({
    models: [modelSpec('openai', 'gpt-5-nano', 'unused')],
    cases: [fallbackCase],
    runs: 1,
  });

  const run = execution.report.report[0]!;
  const result = run.results[0]!;
  assert.equal(run.passed, 0);
  assert.equal(run.operationalPassed, 0);
  assert.equal(run.servedPassed, 1);
  assert.equal(run.recovered, 0);
  assert.equal(run.fallbackRecovered, 1);
  assert.equal(result.status, 'failed');
  assert.equal(result.operationalStatus, 'failed');
  assert.equal(result.servedStatus, 'passed');
  assert.equal(result.recovery?.status, 'failed');
  assert.equal(result.fallback?.status, 'passed');
  assert.equal(run.inputTokenCount, 20);
  assert.equal(run.outputTokenCount, 10);
  assert.equal(run.latencyMs, 40);
  assert.equal(execution.hasFailure, true);
  assert.equal(execution.hasOperationalFailure, true);
  assert.equal(execution.hasServedFailure, false);
});

test('model evaluation does not recover evaluation-only expectation failures', async () => {
  let recoveryCount = 0;
  const expectationFailureCase: ModelEvaluationCase = {
    ...evaluationCase,
    name: 'evaluation_only_failure',
    run: async () => modelResult('평가 기대어가 빠진 정상 출력', 1, 'stop'),
    validateForRecovery: () => {},
    recoverValidation: async () => {
      recoveryCount += 1;
      return modelResult('통과', 1, 'stop');
    },
  };
  const execution = await runModelEvaluation({
    models: [modelSpec('groq', 'openai/gpt-oss-120b', 'unused')],
    cases: [expectationFailureCase],
    runs: 1,
  });

  const result = execution.report.report[0]!.results[0]!;
  assert.equal(recoveryCount, 0);
  assert.equal(result.status, 'failed');
  assert.equal(result.operationalStatus, 'failed');
  assert.equal(result.servedStatus, 'failed');
  assert.equal(result.recovery, null);
  assert.equal(result.fallback, null);
  assert.equal(execution.hasOperationalFailure, true);
  assert.equal(execution.hasServedFailure, true);
});

test('model evaluation retries one retryable generation failure', async () => {
  let callCount = 0;
  const retryableCase: ModelEvaluationCase = {
    ...evaluationCase,
    name: 'retryable_generation',
    run: async () => {
      callCount += 1;
      if (callCount === 1) {
        throw new LearningModelError({
          code: 'model_network_error',
          retryable: true,
          usage: {
            inputTokenCount: null,
            outputTokenCount: null,
            latencyMs: 50,
          },
        });
      }
      return modelResult('통과', 1, 'stop');
    },
  };
  const execution = await runModelEvaluation({
    models: [modelSpec('groq', 'openai/gpt-oss-120b', 'unused')],
    cases: [retryableCase],
    runs: 1,
  });

  const result = execution.report.report[0]!.results[0]!;
  assert.equal(callCount, 2);
  assert.equal(result.failurePhase, 'generation');
  assert.equal(result.operationalStatus, 'passed');
  assert.equal(result.recovery?.status, 'passed');
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

function modelResult(
  text: string,
  providerAttemptCount: number,
  completionReason: string,
): LearningModelResult<unknown> {
  return {
    value: { text },
    usage: {
      inputTokenCount: 10,
      outputTokenCount: 5,
      latencyMs: 20,
    },
    diagnostics: {
      providerAttemptCount,
      completionReason,
    },
  };
}
