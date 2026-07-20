import {
  anonymizeCompletedQuestionContext,
  resolveMemoryCandidates,
  validateCoupleFeedback,
  validatePersonalizedQuestion,
  validateQuestionRecommendation,
  type CompletedQuestionContext,
} from '../domain/learning-contract.ts';
import {
  GeminiOutputError,
  GeminiProviderError,
} from '../infrastructure/gemini-interactions-client.ts';
import type {
  LearningModelPort,
  LearningModelUsage,
} from './learning-model-port.ts';

export type LearningJobType =
  | 'extract_memories'
  | 'generate_feedback'
  | 'select_curated_question'
  | 'generate_personalized_question'
  | 'rebuild_profile';

export interface ClaimedLearningJob {
  jobId: string;
  coupleId: string;
  dailyQuestionId: string | null;
  jobType: LearningJobType;
  attempt: number;
  leaseExpiresAt: string;
}

export interface RunSuccess {
  runId: string;
  output: Record<string, unknown>;
  usage: LearningModelUsage;
}

export interface RunFailure {
  runId: string;
  errorCode: string;
  safetyStatus: 'flagged' | 'error';
  retryable: boolean;
  providerHttpStatus: number | null;
  providerErrorStatus: string | null;
  retryAfterMs: number | null;
  usage: LearningModelUsage;
}

export interface LearningJobRepository {
  claimJobs(workerId: string, limit: number): Promise<ClaimedLearningJob[]>;
  loadContext(jobId: string): Promise<CompletedQuestionContext>;
  startRun(
    job: ClaimedLearningJob,
    provider: string,
    model: string,
    promptVersion: string,
  ): Promise<string>;
  succeedRun(success: RunSuccess): Promise<boolean>;
  failRun(failure: RunFailure): Promise<boolean>;
  failClaimedJob(
    jobId: string,
    errorCode: string,
    retryable: boolean,
  ): Promise<boolean>;
  expandRebuild(jobId: string): Promise<boolean>;
}

export interface LearningJobBatchSummary {
  claimed: number;
  succeeded: number;
  retried: number;
  failed: number;
}

interface LearningJobProcessorOptions {
  repository: LearningJobRepository;
  model: LearningModelPort;
  workerId: string;
  provider: string;
  modelName: string;
}

interface ClassifiedFailure {
  errorCode: string;
  safetyStatus: 'flagged' | 'error';
  retryable: boolean;
  providerHttpStatus: number | null;
  providerErrorStatus: string | null;
  retryAfterMs: number | null;
  usage: LearningModelUsage;
}

const emptyUsage: LearningModelUsage = {
  inputTokenCount: null,
  outputTokenCount: null,
  latencyMs: 0,
};

const promptVersions: Record<Exclude<LearningJobType, 'rebuild_profile'>, string> = {
  extract_memories: 'memory-v1',
  generate_feedback: 'feedback-v1',
  select_curated_question: 'question-ranking-v1',
  generate_personalized_question: 'personalized-question-v1',
};

export class AiRepositoryError extends Error {
  readonly code: string;
  readonly retryable: boolean;

  constructor(params: { code: string; retryable: boolean; cause?: unknown }) {
    super(params.code, { cause: params.cause });
    this.name = 'AiRepositoryError';
    this.code = params.code;
    this.retryable = params.retryable;
  }
}

export class LearningJobProcessor {
  readonly #repository: LearningJobRepository;
  readonly #model: LearningModelPort;
  readonly #workerId: string;
  readonly #provider: string;
  readonly #modelName: string;

  constructor(options: LearningJobProcessorOptions) {
    this.#repository = options.repository;
    this.#model = options.model;
    this.#workerId = requireNonBlank(options.workerId, 'worker id', 120);
    this.#provider = requireNonBlank(options.provider, 'provider', 100);
    this.#modelName = requireNonBlank(options.modelName, 'model', 160);
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
        if (job.jobType === 'rebuild_profile') {
          const expanded = await this.#repository.expandRebuild(job.jobId);
          if (!expanded) {
            throw new AiRepositoryError({
              code: 'ai_rebuild_not_completed',
              retryable: true,
            });
          }
          summary.succeeded += 1;
          continue;
        }

        const context = await this.#repository.loadContext(job.jobId);
        const modelContext = anonymizeCompletedQuestionContext(context);
        runId = await this.#repository.startRun(
          job,
          this.#provider,
          this.#modelName,
          promptVersions[job.jobType],
        );

        const execution = await this.#executeModelTask(
          job.jobType,
          context,
          modelContext,
        );
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

        summary.succeeded += 1;
      } catch (error) {
        const failure = classifyFailure(error, usage);
        usage = failure.usage;
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
            retryAfterMs: failure.retryAfterMs,
            usage,
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

  async #executeModelTask(
    jobType: Exclude<LearningJobType, 'rebuild_profile'>,
    context: CompletedQuestionContext,
    modelContext: ReturnType<typeof anonymizeCompletedQuestionContext>,
  ): Promise<{
    output: Record<string, unknown>;
    usage: LearningModelUsage;
  }> {
    if (jobType === 'extract_memories') {
      const result = await this.#model.extractMemoryCandidates(modelContext);
      const resolved = resolveMemoryCandidates(context, result.value);
      return {
        output: {
          memories: resolved.map((memory) => ({
            memory_key: memory.memoryKey,
            scope: memory.scope,
            subject_user_id: memory.subjectUserId,
            kind: memory.kind,
            statement: memory.statement,
            confidence: memory.confidence,
            evidence_answer_ids: memory.evidenceAnswerIds,
          })),
        },
        usage: result.usage,
      };
    }

    if (jobType === 'generate_feedback') {
      const result = await this.#model.generateCoupleFeedback(modelContext);
      validateCoupleFeedback(result.value);
      return {
        output: { feedback_text: result.value.text },
        usage: result.usage,
      };
    }

    if (jobType === 'select_curated_question') {
      const result = await this.#model.rankFoundationQuestions(
        modelContext,
        context.remainingFoundationQuestions,
      );
      validateQuestionRecommendation(
        context.remainingFoundationQuestions,
        result.value.questionKey,
      );
      return {
        output: {
          question_key: result.value.questionKey,
          rationale: requireNonBlank(
            result.value.rationale,
            'question rationale',
            500,
          ),
        },
        usage: result.usage,
      };
    }

    const result = await this.#model.generatePersonalizedQuestion(modelContext);
    validatePersonalizedQuestion(result.value);
    return {
      output: {
        question_key: result.value.questionKey,
        question_text: result.value.text,
        category: result.value.category,
        mood: result.value.mood,
        rationale: result.value.rationale,
      },
      usage: result.usage,
    };
  }
}

function classifyFailure(
  error: unknown,
  fallbackUsage: LearningModelUsage,
): ClassifiedFailure {
  if (error instanceof GeminiProviderError) {
    return {
      errorCode: error.code,
      safetyStatus: 'error',
      retryable: error.retryable,
      providerHttpStatus: error.status,
      providerErrorStatus: error.providerStatus,
      retryAfterMs: error.retryAfterMs,
      usage: {
        inputTokenCount: null,
        outputTokenCount: null,
        latencyMs: error.latencyMs,
      },
    };
  }
  if (error instanceof GeminiOutputError) {
    return {
      errorCode: error.code,
      safetyStatus: 'error',
      retryable: error.retryable,
      providerHttpStatus: null,
      providerErrorStatus: null,
      retryAfterMs: null,
      usage: {
        inputTokenCount: null,
        outputTokenCount: null,
        latencyMs: error.latencyMs,
      },
    };
  }
  if (error instanceof AiRepositoryError) {
    return {
      errorCode: error.code,
      safetyStatus: 'error',
      retryable: error.retryable,
      providerHttpStatus: null,
      providerErrorStatus: null,
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
