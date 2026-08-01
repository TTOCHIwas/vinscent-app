import type {
  LearningModelPort,
} from '../src/application/learning-model-port.ts';
import type {
  ModelEvaluationCase,
  ModelEvaluationSource,
  ModelEvaluationTask,
} from './cloudflare-model-eval-case.ts';
import {
  runEvaluationCase,
  type EvaluationCaseResult,
} from './cloudflare-model-eval-support.ts';

export interface EvaluationModelSpec {
  provider: string;
  model: string;
  caseDelayMs?: number;
  createModel(): LearningModelPort;
}

export interface DetailedEvaluationCaseResult extends EvaluationCaseResult {
  task: ModelEvaluationTask;
  scenario: string;
  source: ModelEvaluationSource;
  expectation: string;
}

export interface TaskSummary {
  passed: number;
  total: number;
  inputTokenCount: number | null;
  outputTokenCount: number | null;
  latencyMs: number;
}

export interface ModelEvaluationRun {
  provider: string;
  model: string;
  run: number;
  passed: number;
  total: number;
  inputTokenCount: number | null;
  outputTokenCount: number | null;
  latencyMs: number;
  taskSummary: Partial<Record<ModelEvaluationTask, TaskSummary>>;
  results: DetailedEvaluationCaseResult[];
}

export interface ModelEvaluationReport {
  generatedAt: string;
  syntheticDataOnly: true;
  distinctScenarioCount: number;
  taskCount: number;
  productionRegressionCount: number;
  representativeBoundaryCount: number;
  report: ModelEvaluationRun[];
}

export interface ModelEvaluationExecution {
  report: ModelEvaluationReport;
  hasFailure: boolean;
}

export async function runModelEvaluation(options: {
  models: EvaluationModelSpec[];
  cases: ModelEvaluationCase[];
  runs: number;
  now?: () => Date;
  wait?: (delayMs: number) => Promise<void>;
}): Promise<ModelEvaluationExecution> {
  if (options.models.length === 0) {
    throw new RangeError('At least one evaluation model is required');
  }
  if (options.cases.length === 0) {
    throw new RangeError('At least one evaluation case is required');
  }
  if (!Number.isInteger(options.runs) || options.runs < 1) {
    throw new RangeError('Evaluation runs must be a positive integer');
  }

  const report: ModelEvaluationRun[] = [];
  let hasFailure = false;
  const wait = options.wait ?? waitFor;

  for (const modelSpec of options.models) {
    const provider = requireLabel(modelSpec.provider, 'provider');
    const modelName = requireLabel(modelSpec.model, 'model');
    const caseDelayMs = requireCaseDelay(modelSpec.caseDelayMs);
    for (let run = 1; run <= options.runs; run += 1) {
      const model = modelSpec.createModel();
      const results: DetailedEvaluationCaseResult[] = [];

      for (const evaluationCase of options.cases) {
        if (caseDelayMs > 0) {
          await wait(caseDelayMs);
        }
        const result = await runEvaluationCase({
          name: evaluationCase.name,
          execute: () => evaluationCase.run(model),
          validate: evaluationCase.validate,
        });
        results.push({
          task: evaluationCase.task,
          scenario: evaluationCase.scenario,
          source: evaluationCase.source,
          expectation: evaluationCase.expectation,
          ...result,
        });
        hasFailure ||= result.status === 'failed';
      }

      report.push({
        provider,
        model: modelName,
        run,
        passed: results.filter((result) => result.status === 'passed').length,
        total: results.length,
        inputTokenCount: sumKnownTokens(
          results.map((result) => result.inputTokenCount),
        ),
        outputTokenCount: sumKnownTokens(
          results.map((result) => result.outputTokenCount),
        ),
        latencyMs: results.reduce(
          (total, result) => total + result.latencyMs,
          0,
        ),
        taskSummary: summarizeTasks(results),
        results,
      });
    }
  }

  return {
    hasFailure,
    report: {
      generatedAt: (options.now?.() ?? new Date()).toISOString(),
      syntheticDataOnly: true,
      distinctScenarioCount: options.cases.length,
      taskCount: new Set(options.cases.map((item) => item.task)).size,
      productionRegressionCount: options.cases.filter(
        (item) => item.source === 'production_regression',
      ).length,
      representativeBoundaryCount: options.cases.filter(
        (item) => item.source === 'representative_boundary',
      ).length,
      report,
    },
  };
}

function summarizeTasks(
  results: DetailedEvaluationCaseResult[],
): Partial<Record<ModelEvaluationTask, TaskSummary>> {
  const summary: Partial<Record<ModelEvaluationTask, TaskSummary>> = {};
  for (const task of new Set(results.map((result) => result.task))) {
    const taskResults = results.filter((result) => result.task === task);
    summary[task] = {
      passed: taskResults.filter((result) => result.status === 'passed').length,
      total: taskResults.length,
      inputTokenCount: sumKnownTokens(
        taskResults.map((result) => result.inputTokenCount),
      ),
      outputTokenCount: sumKnownTokens(
        taskResults.map((result) => result.outputTokenCount),
      ),
      latencyMs: taskResults.reduce(
        (total, result) => total + result.latencyMs,
        0,
      ),
    };
  }
  return summary;
}

function sumKnownTokens(values: Array<number | null>): number | null {
  let total = 0;
  for (const value of values) {
    if (value === null) {
      return null;
    }
    total += value;
  }
  return total;
}

function requireLabel(value: string, name: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new TypeError(`Evaluation ${name} is required`);
  }
  return normalized;
}

function requireCaseDelay(value: number | undefined): number {
  const delayMs = value ?? 0;
  if (!Number.isInteger(delayMs) || delayMs < 0) {
    throw new RangeError('Evaluation case delay must be a non-negative integer');
  }
  return delayMs;
}

async function waitFor(delayMs: number): Promise<void> {
  await new Promise<void>((resolve) => setTimeout(resolve, delayMs));
}
