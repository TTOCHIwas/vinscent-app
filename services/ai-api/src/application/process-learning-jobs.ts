import type {
  LearningJobExecutionDiagnostic,
  LearningJobHandlerRegistry,
} from './learning-job-handler.ts';
import {
  createDefaultLearningJobHandlerRegistry,
} from './learning-job-handlers.ts';
import { LearningJobExecutionError } from './learning-job-execution-error.ts';
import {
  AiRepositoryError,
  type LearningJobRepository,
} from './learning-job-repository.ts';
import {
  LearningModelError,
  type LearningModelPort,
  type LearningModelUsage,
} from './learning-model-port.ts';

export {
  AiRepositoryError,
} from './learning-job-repository.ts';
export type {
  ClaimedLearningJob,
  LearningJobRepository,
  LearningJobType,
  RunFailure,
  RunSuccess,
} from './learning-job-repository.ts';

export interface LearningJobBatchSummary {
  claimed: number;
  succeeded: number;
  retried: number;
  failed: number;
}

export interface LearningJobOperationalDiagnostic {
  event:
    | 'ai_learning_feedback_fallback'
    | 'ai_learning_personalized_question_fallback';
  jobId: string;
  runId: string;
  jobAttempt: number;
  promptVersion: string;
  rejectionCodes: readonly string[];
}

interface LearningJobProcessorOptions {
  repository: LearningJobRepository;
  model: LearningModelPort;
  workerId: string;
  provider: string;
  modelName: string;
  handlerRegistry?: LearningJobHandlerRegistry;
  onDiagnostic?: (diagnostic: LearningJobOperationalDiagnostic) => void;
}

interface ClassifiedFailure {
  errorCode: string;
  safetyStatus: 'flagged' | 'error';
  retryable: boolean;
  providerHttpStatus: number | null;
  providerErrorStatus: string | null;
  providerErrorDetail: string | null;
  retryAfterMs: number | null;
  usage: LearningModelUsage;
}

const emptyUsage: LearningModelUsage = {
  inputTokenCount: null,
  outputTokenCount: null,
  latencyMs: 0,
};

export class LearningJobProcessor {
  readonly #repository: LearningJobRepository;
  readonly #handlerRegistry: LearningJobHandlerRegistry;
  readonly #workerId: string;
  readonly #provider: string;
  readonly #modelName: string;
  readonly #onDiagnostic: (
    diagnostic: LearningJobOperationalDiagnostic,
  ) => void;

  constructor(options: LearningJobProcessorOptions) {
    this.#repository = options.repository;
    this.#handlerRegistry = options.handlerRegistry
      ?? createDefaultLearningJobHandlerRegistry({
        repository: options.repository,
        model: options.model,
      });
    this.#workerId = requireNonBlank(options.workerId, 'worker id', 120);
    this.#provider = requireNonBlank(options.provider, 'provider', 100);
    this.#modelName = requireNonBlank(options.modelName, 'model', 160);
    this.#onDiagnostic = options.onDiagnostic ?? (() => {});
  }

  async processBatch(limit: number): Promise<LearningJobBatchSummary> {
    if (!Number.isInteger(limit) || limit < 1 || limit > 20) {
      throw new RangeError('job batch limit must be between 1 and 20');
    }

    const jobs = await this.#repository.claimJobs(this.#workerId, limit);
    const summary: LearningJobBatchSummary = {
      claimed: jobs.length,
      succeeded: 0,
      retried: 0,
      failed: 0,
    };

    for (const job of jobs) {
      let runId: string | null = null;
      let usage = emptyUsage;

      try {
        const handler = this.#handlerRegistry.handlerFor(job.jobType);
        const prepared = await handler.prepare(job);

        if (prepared.kind === 'maintenance') {
          await prepared.execute();
          summary.succeeded += 1;
          continue;
        }

        const promptVersion = requireNonBlank(
          prepared.promptVersion,
          'prompt version',
          160,
        );
        runId = await this.#repository.startRun(
          job,
          this.#provider,
          this.#modelName,
          promptVersion,
        );
        const execution = await prepared.execute();
        usage = execution.usage;
        const completed = await this.#repository.succeedRun({
          runId,
          output: execution.output,
          usage,
        });
        if (!completed) {
          throw new AiRepositoryError({
            code: 'ai_run_not_completed',
            retryable: true,
          });
        }

        this.#reportDiagnostics(
          job.jobId,
          runId,
          job.attempt,
          promptVersion,
          execution.diagnostics,
        );
        summary.succeeded += 1;
      } catch (error) {
        const failure = classifyFailure(error, usage);
        if (runId === null) {
          await this.#repository.failClaimedJob(
            job.jobId,
            failure.errorCode,
            failure.retryable,
          );
        } else {
          await this.#repository.failRun({
            runId,
            errorCode: failure.errorCode,
            safetyStatus: failure.safetyStatus,
            retryable: failure.retryable,
            providerHttpStatus: failure.providerHttpStatus,
            providerErrorStatus: failure.providerErrorStatus,
            providerErrorDetail: failure.providerErrorDetail,
            retryAfterMs: failure.retryAfterMs,
            usage: failure.usage,
          });
        }

        if (failure.retryable) {
          summary.retried += 1;
        } else {
          summary.failed += 1;
        }
      }
    }

    return summary;
  }

  #reportDiagnostics(
    jobId: string,
    runId: string,
    jobAttempt: number,
    promptVersion: string,
    diagnostics: readonly LearningJobExecutionDiagnostic[] | undefined,
  ): void {
    for (const diagnostic of diagnostics ?? []) {
      reportDiagnosticSafely(this.#onDiagnostic, {
        event: diagnostic.kind === 'couple_feedback_fallback'
          ? 'ai_learning_feedback_fallback'
          : 'ai_learning_personalized_question_fallback',
        jobId,
        runId,
        jobAttempt,
        promptVersion,
        rejectionCodes: [...diagnostic.rejectionCodes],
      });
    }
  }
}

function reportDiagnosticSafely(
  observer: (diagnostic: LearningJobOperationalDiagnostic) => void,
  diagnostic: LearningJobOperationalDiagnostic,
): void {
  try {
    observer(diagnostic);
  } catch (_) {
    return;
  }
}

function classifyFailure(
  error: unknown,
  fallbackUsage: LearningModelUsage,
): ClassifiedFailure {
  if (error instanceof LearningModelError) {
    return {
      errorCode: error.code,
      safetyStatus: error.code === 'model_content_blocked'
        ? 'flagged'
        : 'error',
      retryable: error.retryable,
      providerHttpStatus: error.providerHttpStatus,
      providerErrorStatus: error.providerErrorStatus,
      providerErrorDetail: error.diagnosticDetail,
      retryAfterMs: error.retryAfterMs,
      usage: error.usage,
    };
  }
  if (error instanceof LearningJobExecutionError) {
    return {
      errorCode: error.code,
      safetyStatus: 'error',
      retryable: error.retryable,
      providerHttpStatus: null,
      providerErrorStatus: null,
      providerErrorDetail: null,
      retryAfterMs: null,
      usage: error.usage,
    };
  }
  if (error instanceof AiRepositoryError) {
    return {
      errorCode: error.code,
      safetyStatus: 'error',
      retryable: error.retryable,
      providerHttpStatus: null,
      providerErrorStatus: null,
      providerErrorDetail: null,
      retryAfterMs: null,
      usage: fallbackUsage,
    };
  }
  if (error instanceof RangeError || error instanceof TypeError) {
    return {
      errorCode: 'model_contract_invalid',
      safetyStatus: 'error',
      retryable: false,
      providerHttpStatus: null,
      providerErrorStatus: null,
      providerErrorDetail: null,
      retryAfterMs: null,
      usage: fallbackUsage,
    };
  }
  if (error instanceof Error) {
    return {
      errorCode: 'model_contract_invalid',
      safetyStatus: 'error',
      retryable: false,
      providerHttpStatus: null,
      providerErrorStatus: null,
      providerErrorDetail: null,
      retryAfterMs: null,
      usage: fallbackUsage,
    };
  }
  return {
    errorCode: 'ai_worker_unexpected',
    safetyStatus: 'error',
    retryable: true,
    providerHttpStatus: null,
    providerErrorStatus: null,
    providerErrorDetail: null,
    retryAfterMs: null,
    usage: fallbackUsage,
  };
}

function requireNonBlank(
  value: string,
  name: string,
  maximum: number,
): string {
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maximum) {
    throw new RangeError(`${name} must contain 1 to ${maximum} characters`);
  }
  return normalized;
}
