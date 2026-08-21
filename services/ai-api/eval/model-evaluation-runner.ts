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
  configuration?: Readonly<Record<
    string,
    string | number | boolean
  >>;
  createModel(): LearningModelPort;
}

export interface DetailedEvaluationCaseResult extends EvaluationCaseResult {
  task: ModelEvaluationTask;
  scenario: string;
  source: ModelEvaluationSource;
  expectation: string;
  operationalStatus: 'passed' | 'failed';
  servedStatus: 'passed' | 'failed';
  recovery: EvaluationCaseResult | null;
  fallback: EvaluationCaseResult | null;
}

export interface TaskSummary {
  passed: number;
  operationalPassed: number;
  servedPassed: number;
  recovered: number;
  fallbackRecovered: number;
  total: number;
  inputTokenCount: number | null;
  outputTokenCount: number | null;
  latencyMs: number;
}

export interface ModelEvaluationRun {
  provider: string;
  model: string;
  configuration: Record<string, string | number | boolean>;
  run: number;
  passed: number;
  operationalPassed: number;
  servedPassed: number;
  recovered: number;
  fallbackRecovered: number;
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
  hasOperationalFailure: boolean;
  hasServedFailure: boolean;
}

export interface ModelEvaluationProgress {
  provider: string;
  model: string;
  modelIndex: number;
  modelCount: number;
  run: number;
  runCount: number;
  caseIndex: number;
  caseCount: number;
  result: DetailedEvaluationCaseResult;
}

export async function runModelEvaluation(options: {
  models: EvaluationModelSpec[];
  cases: ModelEvaluationCase[];
  runs: number;
  now?: () => Date;
  wait?: (delayMs: number) => Promise<void>;
  onCaseComplete?: (
    progress: ModelEvaluationProgress,
  ) => void | Promise<void>;
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
  let hasOperationalFailure = false;
  let hasServedFailure = false;
  const wait = options.wait ?? waitFor;

  for (
    let modelIndex = 0;
    modelIndex < options.models.length;
    modelIndex += 1
  ) {
    const modelSpec = options.models[modelIndex]!;
    const provider = requireLabel(modelSpec.provider, 'provider');
    const modelName = requireLabel(modelSpec.model, 'model');
    const caseDelayMs = requireCaseDelay(modelSpec.caseDelayMs);
    const configuration = normalizeConfiguration(modelSpec.configuration);
    for (let run = 1; run <= options.runs; run += 1) {
      const model = modelSpec.createModel();
      const results: DetailedEvaluationCaseResult[] = [];

      for (
        let caseIndex = 0;
        caseIndex < options.cases.length;
        caseIndex += 1
      ) {
        const evaluationCase = options.cases[caseIndex]!;
        if (caseDelayMs > 0) {
          await wait(caseDelayMs);
        }
        const firstPassResult = await runEvaluationCase({
          name: evaluationCase.name,
          execute: () => evaluationCase.run(model),
          validate: evaluationCase.validate,
        });
        const recovery = await recoverEvaluationCase({
          evaluationCase,
          firstPassResult,
          model,
          caseDelayMs,
          wait,
        });
        const operationalStatus = recovery?.status
          ?? firstPassResult.status;
        const fallback = await resolveEvaluationFallback({
          evaluationCase,
          recovery,
        });
        const servedStatus = fallback?.status ?? operationalStatus;
        const detailedResult = {
          task: evaluationCase.task,
          scenario: evaluationCase.scenario,
          source: evaluationCase.source,
          expectation: evaluationCase.expectation,
          ...firstPassResult,
          operationalStatus,
          servedStatus,
          recovery,
          fallback,
        };
        results.push(detailedResult);
        hasFailure ||= firstPassResult.status === 'failed';
        hasOperationalFailure ||= operationalStatus === 'failed';
        hasServedFailure ||= servedStatus === 'failed';
        await options.onCaseComplete?.({
          provider,
          model: modelName,
          modelIndex: modelIndex + 1,
          modelCount: options.models.length,
          run,
          runCount: options.runs,
          caseIndex: caseIndex + 1,
          caseCount: options.cases.length,
          result: detailedResult,
        });
      }

      report.push({
        provider,
        model: modelName,
        configuration,
        run,
        passed: results.filter((result) => result.status === 'passed').length,
        operationalPassed: results.filter(
          (result) => result.operationalStatus === 'passed',
        ).length,
        servedPassed: results.filter(
          (result) => result.servedStatus === 'passed',
        ).length,
        recovered: results.filter(
          (result) => result.status === 'failed'
            && result.operationalStatus === 'passed',
        ).length,
        fallbackRecovered: results.filter(
          (result) => result.operationalStatus === 'failed'
            && result.servedStatus === 'passed',
        ).length,
        total: results.length,
        inputTokenCount: sumKnownTokens(
          usageValues(results, 'inputTokenCount'),
        ),
        outputTokenCount: sumKnownTokens(
          usageValues(results, 'outputTokenCount'),
        ),
        latencyMs: results.reduce(
          (total, result) => total
            + result.latencyMs
            + (result.recovery?.latencyMs ?? 0)
            + (result.fallback?.latencyMs ?? 0),
          0,
        ),
        taskSummary: summarizeTasks(results),
        results,
      });
    }
  }

  return {
    hasFailure,
    hasOperationalFailure,
    hasServedFailure,
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

function normalizeConfiguration(
  configuration: EvaluationModelSpec['configuration'],
): Record<string, string | number | boolean> {
  if (configuration === undefined) {
    return {};
  }

  const normalized: Record<string, string | number | boolean> = {};
  for (const [key, value] of Object.entries(configuration)) {
    const normalizedKey = key.trim();
    if (normalizedKey.length === 0) {
      throw new TypeError('Evaluation configuration key is required');
    }
    if (
      typeof value !== 'string'
      && typeof value !== 'number'
      && typeof value !== 'boolean'
    ) {
      throw new TypeError(
        'Evaluation configuration value must be a scalar',
      );
    }
    if (typeof value === 'number' && !Number.isFinite(value)) {
      throw new TypeError(
        'Evaluation configuration number must be finite',
      );
    }
    normalized[normalizedKey] = value;
  }
  return normalized;
}

function summarizeTasks(
  results: DetailedEvaluationCaseResult[],
): Partial<Record<ModelEvaluationTask, TaskSummary>> {
  const summary: Partial<Record<ModelEvaluationTask, TaskSummary>> = {};
  for (const task of new Set(results.map((result) => result.task))) {
    const taskResults = results.filter((result) => result.task === task);
    summary[task] = {
      passed: taskResults.filter((result) => result.status === 'passed').length,
      operationalPassed: taskResults.filter(
        (result) => result.operationalStatus === 'passed',
      ).length,
      servedPassed: taskResults.filter(
        (result) => result.servedStatus === 'passed',
      ).length,
      recovered: taskResults.filter(
        (result) => result.status === 'failed'
          && result.operationalStatus === 'passed',
      ).length,
      fallbackRecovered: taskResults.filter(
        (result) => result.operationalStatus === 'failed'
          && result.servedStatus === 'passed',
      ).length,
      total: taskResults.length,
      inputTokenCount: sumKnownTokens(
        usageValues(taskResults, 'inputTokenCount'),
      ),
      outputTokenCount: sumKnownTokens(
        usageValues(taskResults, 'outputTokenCount'),
      ),
      latencyMs: taskResults.reduce(
        (total, result) => total
          + result.latencyMs
          + (result.recovery?.latencyMs ?? 0)
          + (result.fallback?.latencyMs ?? 0),
        0,
      ),
    };
  }
  return summary;
}

function usageValues(
  results: DetailedEvaluationCaseResult[],
  field: 'inputTokenCount' | 'outputTokenCount',
): Array<number | null> {
  return results.flatMap((result) => [
    result[field],
    ...(result.recovery === null ? [] : [result.recovery[field]]),
    ...(result.fallback === null ? [] : [result.fallback[field]]),
  ]);
}

async function resolveEvaluationFallback(options: {
  evaluationCase: ModelEvaluationCase;
  recovery: EvaluationCaseResult | null;
}): Promise<EvaluationCaseResult | null> {
  const { evaluationCase, recovery } = options;
  if (
    recovery === null
    || recovery.status === 'passed'
    || evaluationCase.resolveFallback === undefined
    || !hasFallbackEligibleFailure(evaluationCase, recovery)
  ) {
    return null;
  }

  const fallback = await evaluationCase.resolveFallback(
    recovery.output,
    recovery.error?.code ?? null,
  );
  if (fallback === null) {
    return null;
  }

  return runEvaluationCase({
    name: evaluationCase.name,
    execute: async () => fallback,
    validate: evaluationCase.validateForRecovery ?? evaluationCase.validate,
  });
}

async function recoverEvaluationCase(options: {
  evaluationCase: ModelEvaluationCase;
  firstPassResult: EvaluationCaseResult;
  model: LearningModelPort;
  caseDelayMs: number;
  wait(delayMs: number): Promise<void>;
}): Promise<EvaluationCaseResult | null> {
  const { evaluationCase, firstPassResult } = options;
  if (firstPassResult.status === 'passed') {
    return null;
  }

  const retryGeneration = firstPassResult.failurePhase === 'generation'
    && firstPassResult.error?.retryable === true;
  const recoverInvalidOutput = firstPassResult.failurePhase === 'generation'
    && firstPassResult.error?.code === 'model_invalid_output'
    && evaluationCase.recoverGeneration !== undefined;
  const recoverValidation = firstPassResult.failurePhase === 'validation'
    && evaluationCase.recoverValidation !== undefined;
  const failedOperationalValidation = recoverValidation
    && hasOperationalValidationFailure(
      evaluationCase,
      firstPassResult.output,
    );
  if (
    !retryGeneration
    && !recoverInvalidOutput
    && !failedOperationalValidation
  ) {
    return null;
  }

  if (options.caseDelayMs > 0) {
    await options.wait(options.caseDelayMs);
  }

  let execute: ModelEvaluationCase['run'];
  if (retryGeneration) {
    execute = () => evaluationCase.run(options.model);
  } else if (recoverInvalidOutput) {
    const recoverGeneration = evaluationCase.recoverGeneration!;
    const rejectionCode = firstPassResult.error!.code!;
    execute = () => recoverGeneration(options.model, rejectionCode);
  } else {
    const recoverValidation = evaluationCase.recoverValidation!;
    execute = () => recoverValidation(
      options.model,
      firstPassResult.output,
      firstPassResult.error?.code ?? null,
    );
  }

  return runEvaluationCase({
    name: evaluationCase.name,
    execute,
    validate: evaluationCase.validate,
  });
}

function hasFallbackEligibleFailure(
  evaluationCase: ModelEvaluationCase,
  result: EvaluationCaseResult,
): boolean {
  if (
    result.failurePhase === 'generation'
    && result.error?.code === 'model_invalid_output'
  ) {
    return true;
  }
  return result.failurePhase === 'validation'
    && evaluationCase.validateForRecovery !== undefined
    && hasOperationalValidationFailure(evaluationCase, result.output);
}

function hasOperationalValidationFailure(
  evaluationCase: ModelEvaluationCase,
  output: unknown,
): boolean {
  if (evaluationCase.validateForRecovery === undefined) {
    return false;
  }
  try {
    evaluationCase.validateForRecovery(output);
    return false;
  } catch {
    return true;
  }
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
