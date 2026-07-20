import {
  AiRepositoryError,
  type ClaimedLearningJob,
  type LearningJobRepository,
  type LearningJobType,
  type RunFailure,
  type RunSuccess,
} from '../application/process-learning-jobs.ts';
import type {
  CompletedQuestionContext,
  LearningDomain,
} from '../domain/learning-contract.ts';

interface SupabaseRpcResult {
  data: unknown;
  error: unknown;
}

export interface SupabaseRpcClient {
  rpc(
    name: string,
    params?: Record<string, unknown>,
  ): PromiseLike<SupabaseRpcResult>;
}

const learningDomains = new Set<LearningDomain>([
  'personal_values',
  'emotional_support',
  'communication_repair',
  'daily_life',
  'relationship_strength',
  'future_boundaries',
]);

const learningJobTypes = new Set<LearningJobType>([
  'extract_memories',
  'generate_feedback',
  'select_curated_question',
  'generate_personalized_question',
  'rebuild_profile',
]);

export class SupabaseLearningJobRepository implements LearningJobRepository {
  readonly #client: SupabaseRpcClient;

  constructor(client: SupabaseRpcClient) {
    this.#client = client;
  }

  async claimJobs(workerId: string, limit: number): Promise<ClaimedLearningJob[]> {
    const data = await this.#rpc(
      'claim_ai_processing_jobs',
      {
        requested_worker: workerId,
        requested_limit: limit,
      },
      'ai_job_claim_failed',
    );

    if (!Array.isArray(data)) {
      throw repositoryContractError('ai_job_claim_invalid');
    }

    try {
      return data.map(parseClaimedJob);
    } catch (error) {
      throw repositoryContractError('ai_job_claim_invalid', error);
    }
  }

  async loadContext(jobId: string): Promise<CompletedQuestionContext> {
    const data = await this.#rpc(
      'get_ai_processing_job_context',
      { requested_job_id: jobId },
      'ai_context_unavailable',
    );

    try {
      return parseCompletedQuestionContext(data);
    } catch (error) {
      if (error instanceof AiRepositoryError) {
        throw error;
      }
      throw repositoryContractError('ai_context_invalid', error);
    }
  }

  async startRun(
    job: ClaimedLearningJob,
    provider: string,
    model: string,
    promptVersion: string,
  ): Promise<string> {
    const data = await this.#rpc(
      'start_ai_processing_run',
      {
        requested_job_id: job.jobId,
        requested_provider: provider,
        requested_model: model,
        requested_prompt_version: promptVersion,
      },
      'ai_run_start_failed',
    );
    return requireString(data, 160);
  }

  async succeedRun(success: RunSuccess): Promise<boolean> {
    const data = await this.#rpc(
      'succeed_ai_processing_run',
      {
        requested_run_id: success.runId,
        requested_output: success.output,
        requested_input_token_count: success.usage.inputTokenCount,
        requested_output_token_count: success.usage.outputTokenCount,
        requested_latency_ms: success.usage.latencyMs,
      },
      'ai_run_success_failed',
    );
    return requireBoolean(data);
  }

  async failRun(failure: RunFailure): Promise<boolean> {
    const data = await this.#rpc(
      'fail_ai_processing_run',
      {
        requested_run_id: failure.runId,
        requested_error_code: failure.errorCode,
        requested_safety_status: failure.safetyStatus,
        requested_retryable: failure.retryable,
        requested_input_token_count: failure.usage.inputTokenCount,
        requested_output_token_count: failure.usage.outputTokenCount,
        requested_latency_ms: failure.usage.latencyMs,
      },
      'ai_run_failure_record_failed',
    );
    return requireBoolean(data);
  }

  async failClaimedJob(
    jobId: string,
    errorCode: string,
    retryable: boolean,
  ): Promise<boolean> {
    const data = await this.#rpc(
      'complete_ai_processing_job',
      {
        requested_job_id: jobId,
        requested_result: retryable ? 'failed' : 'cancelled',
        requested_error: errorCode,
      },
      'ai_job_failure_record_failed',
    );
    return requireBoolean(data);
  }

  async expandRebuild(jobId: string): Promise<boolean> {
    const data = await this.#rpc(
      'expand_ai_rebuild_profile_job',
      { requested_job_id: jobId },
      'ai_rebuild_failed',
    );
    return requireBoolean(data);
  }

  async #rpc(
    name: string,
    params: Record<string, unknown>,
    errorCode: string,
  ): Promise<unknown> {
    let result: SupabaseRpcResult;
    try {
      result = await this.#client.rpc(name, params);
    } catch (error) {
      throw new AiRepositoryError({
        code: errorCode,
        retryable: true,
        cause: error,
      });
    }

    if (result.error !== null) {
      throw new AiRepositoryError({
        code: errorCode,
        retryable: isRetryableRpcError(result.error),
        cause: result.error,
      });
    }
    return result.data;
  }
}

function parseClaimedJob(value: unknown): ClaimedLearningJob {
  const record = requireRecord(value);
  const jobType = requireJobType(record.job_type);
  const dailyQuestionId = requireNullableString(record.job_daily_question_id, 160);
  const attempt = record.job_attempt;
  if (!Number.isInteger(attempt) || Number(attempt) < 1) {
    throw new TypeError('invalid job attempt');
  }
  if (
    (jobType === 'rebuild_profile' && dailyQuestionId !== null)
    || (jobType !== 'rebuild_profile' && dailyQuestionId === null)
  ) {
    throw new TypeError('invalid job question');
  }

  return {
    jobId: requireString(record.job_id, 160),
    coupleId: requireString(record.job_couple_id, 160),
    dailyQuestionId,
    jobType,
    attempt: Number(attempt),
    leaseExpiresAt: requireString(record.job_lease_expires_at, 100),
  };
}

function parseCompletedQuestionContext(
  value: unknown,
): CompletedQuestionContext {
  const record = requireRecord(value);
  const question = requireRecord(record.question);
  const answers = requireArray(record.answers);
  const memories = requireArray(record.confirmed_memories);
  const remainingQuestions = requireArray(
    record.remaining_foundation_questions,
  );
  if (answers.length !== 2) {
    throw new TypeError('completed context requires two answers');
  }

  return {
    coupleId: requireString(record.couple_id, 160),
    question: {
      dailyQuestionId: requireString(question.daily_question_id, 160),
      questionId: requireString(question.question_id, 160),
      text: requireString(question.text, 4000),
      domain: requireNullableLearningDomain(question.domain),
    },
    answers: answers.map((answer) => {
      const item = requireRecord(answer);
      return {
        answerId: requireString(item.answer_id, 160),
        userId: requireString(item.user_id, 160),
        text: requireString(item.text, 4000),
      };
    }),
    confirmedMemories: memories.map((memory) => {
      const item = requireRecord(memory);
      const scope = item.scope;
      if (scope !== 'personal' && scope !== 'couple') {
        throw new TypeError('invalid memory scope');
      }
      const confidence = item.confidence;
      if (
        typeof confidence !== 'number'
        || !Number.isFinite(confidence)
        || confidence < 0
        || confidence > 1
      ) {
        throw new TypeError('invalid memory confidence');
      }
      const subjectUserId = requireNullableString(item.subject_user_id, 160);
      if (
        (scope === 'personal' && subjectUserId === null)
        || (scope === 'couple' && subjectUserId !== null)
      ) {
        throw new TypeError('invalid memory subject');
      }
      return {
        memoryKey: requireString(item.memory_key, 160),
        scope,
        subjectUserId,
        kind: requireString(item.kind, 100),
        statement: requireString(item.statement, 500),
        confidence,
      };
    }),
    remainingFoundationQuestions: remainingQuestions.map((candidate) => {
      const item = requireRecord(candidate);
      return {
        questionKey: requireString(item.question_key, 120),
        text: requireString(item.text, 4000),
        domain: requireLearningDomain(item.domain),
      };
    }),
  };
}

function requireRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError('expected object');
  }
  return value as Record<string, unknown>;
}

function requireArray(value: unknown): unknown[] {
  if (!Array.isArray(value)) {
    throw new TypeError('expected array');
  }
  return value;
}

function requireBoolean(value: unknown): boolean {
  if (typeof value !== 'boolean') {
    throw repositoryContractError('ai_rpc_result_invalid');
  }
  return value;
}

function requireString(value: unknown, maximum: number): string {
  if (typeof value !== 'string') {
    throw new TypeError('expected string');
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maximum) {
    throw new TypeError('invalid string');
  }
  return normalized;
}

function requireNullableString(
  value: unknown,
  maximum: number,
): string | null {
  return value === null ? null : requireString(value, maximum);
}

function requireLearningDomain(value: unknown): LearningDomain {
  if (typeof value !== 'string' || !learningDomains.has(value as LearningDomain)) {
    throw new TypeError('invalid learning domain');
  }
  return value as LearningDomain;
}

function requireNullableLearningDomain(value: unknown): LearningDomain | null {
  return value === null ? null : requireLearningDomain(value);
}

function requireJobType(value: unknown): LearningJobType {
  if (typeof value !== 'string' || !learningJobTypes.has(value as LearningJobType)) {
    throw new TypeError('invalid learning job type');
  }
  return value as LearningJobType;
}

function repositoryContractError(code: string, cause?: unknown) {
  return new AiRepositoryError({ code, retryable: false, cause });
}

function isRetryableRpcError(error: unknown): boolean {
  const record = typeof error === 'object' && error !== null
    ? error as Record<string, unknown>
    : null;
  const code = typeof record?.code === 'string' ? record.code : '';
  if (
    code === 'P0001'
    || code.startsWith('22')
    || code.startsWith('23')
  ) {
    return false;
  }
  return true;
}
