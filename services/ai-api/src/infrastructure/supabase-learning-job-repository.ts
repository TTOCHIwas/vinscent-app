import {
  AiRepositoryError,
  type ClaimedLearningJob,
  type LearningJobRepository,
  type LearningJobType,
  type RunFailure,
  type RunSuccess,
} from '../application/learning-job-repository.ts';
import type {
  CompletedQuestionContext,
  DirectQuestionContext,
  GeneralQuestionContext,
  LearningDomain,
  MemoryCandidateState,
  MemoryEvidenceType,
  PromptAngle,
  QuestionDepth,
} from '../domain/learning-contract.ts';
import {
  parseDirectQuestionContext,
} from './personalization-context-parser.ts';

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
  'generate_general_question',
  'generate_personalized_question',
  'answer_user_question',
  'rebuild_profile',
]);

const questionDepths = new Set<QuestionDepth>([
  'light',
  'exploratory',
  'deep',
]);

const promptAngles = new Set<PromptAngle>([
  'preference',
  'lived_experience',
  'scenario',
  'current_need',
]);

const memoryEvidenceTypes = new Set<MemoryEvidenceType>([
  'explicit',
  'repeated_pattern',
]);

const memoryCandidateStates = new Set<MemoryCandidateState>([
  'pending',
  'active',
  'rejected',
  'superseded',
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

  async loadGeneralQuestionContext(
    jobId: string,
  ): Promise<GeneralQuestionContext> {
    const data = await this.#rpc(
      'get_ai_general_question_job_context',
      { requested_job_id: jobId },
      'ai_general_question_context_unavailable',
    );

    try {
      return parseGeneralQuestionContext(data);
    } catch (error) {
      if (error instanceof AiRepositoryError) {
        throw error;
      }
      throw repositoryContractError(
        'ai_general_question_context_invalid',
        error,
      );
    }
  }

  async loadDirectQuestionContext(
    jobId: string,
  ): Promise<DirectQuestionContext> {
    const data = await this.#rpc(
      'get_ai_direct_question_job_context',
      { requested_job_id: jobId },
      'ai_direct_question_context_unavailable',
    );

    try {
      return parseDirectQuestionContext(data);
    } catch (error) {
      if (error instanceof AiRepositoryError) {
        throw error;
      }
      throw repositoryContractError(
        'ai_direct_question_context_invalid',
        error,
      );
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
      'fail_ai_processing_run_with_diagnostics_v2',
      {
        requested_run_id: failure.runId,
        requested_error_code: failure.errorCode,
        requested_safety_status: failure.safetyStatus,
        requested_retryable: failure.retryable,
        requested_input_token_count: failure.usage.inputTokenCount,
        requested_output_token_count: failure.usage.outputTokenCount,
        requested_latency_ms: failure.usage.latencyMs,
        requested_provider_http_status: failure.providerHttpStatus,
        requested_provider_error_status: failure.providerErrorStatus,
        requested_provider_error_detail: failure.providerErrorDetail,
        requested_retry_after_ms: failure.retryAfterMs,
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
  const sourceId = requireNullableString(record.job_daily_question_id, 160);
  const attempt = record.job_attempt;
  if (!Number.isInteger(attempt) || Number(attempt) < 1) {
    throw new TypeError('invalid job attempt');
  }
  if (
    (jobType === 'rebuild_profile' && sourceId !== null)
    || (jobType !== 'rebuild_profile' && sourceId === null)
  ) {
    throw new TypeError('invalid job question');
  }

  return {
    jobId: requireString(record.job_id, 160),
    coupleId: requireString(record.job_couple_id, 160),
    sourceId,
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
  const foundationProgress = requireRecord(record.foundation_progress);
  const memories = requireArray(record.confirmed_memories);
  const memoryCandidates = requireArray(record.memory_candidates);
  const recentFoundationQuestions = requireArray(
    record.recent_foundation_questions,
  );
  const recentCompletedQuestions = requireArray(
    record.recent_completed_questions,
  );
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
      depth: requireNullableQuestionDepth(question.depth),
      promptAngle: requireNullablePromptAngle(question.prompt_angle),
    },
    answers: answers.map((answer) => {
      const item = requireRecord(answer);
      return {
        answerId: requireString(item.answer_id, 160),
        userId: requireString(item.user_id, 160),
        text: requireString(item.text, 4000),
      };
    }),
    foundationProgress: parseFoundationProgress(foundationProgress),
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
        domain: requireLearningDomain(item.learning_domain),
        evidenceType: requireMemoryEvidenceType(item.evidence_type),
        statement: requireString(item.statement, 500),
        confidence,
      };
    }),
    memoryCandidates: memoryCandidates.map((memory) => {
      const item = requireRecord(memory);
      const scope = requireMemoryScope(item.scope);
      const subjectUserId = requireNullableString(item.subject_user_id, 160);
      validateMemorySubject(scope, subjectUserId);
      const confidence = requireConfidence(item.confidence);
      const statement = item.statement === null
        ? null
        : requireString(item.statement, 500);
      const evidenceQuestionCount = requireInteger(
        item.evidence_question_count,
        0,
      );

      return {
        memoryKey: requireString(item.memory_key, 160),
        scope,
        subjectUserId,
        kind: requireString(item.kind, 100),
        domain: requireLearningDomain(item.learning_domain),
        evidenceType: requireMemoryEvidenceType(item.evidence_type),
        statement,
        confidence,
        state: requireMemoryCandidateState(item.state),
        evidenceQuestionCount,
      };
    }),
    recentFoundationQuestions: recentFoundationQuestions.map((candidate) => {
      const item = requireRecord(candidate);
      return {
        questionKey: requireString(item.question_key, 120),
        domain: requireLearningDomain(item.domain),
        depth: requireQuestionDepth(item.depth),
        promptAngle: requirePromptAngle(item.prompt_angle),
      };
    }),
    recentCompletedQuestions: recentCompletedQuestions.map((recent) => {
      const item = requireRecord(recent);
      const recentQuestion = requireRecord(item.question);
      const recentAnswers = requireArray(item.answers);
      if (recentAnswers.length !== 2) {
        throw new TypeError('recent completed context requires two answers');
      }
      return {
        question: {
          dailyQuestionId: requireString(
            recentQuestion.daily_question_id,
            160,
          ),
          text: requireString(recentQuestion.text, 4000),
          domain: requireNullableLearningDomain(recentQuestion.domain),
        },
        answers: recentAnswers.map((answer) => {
          const recentAnswer = requireRecord(answer);
          return {
            answerId: requireString(recentAnswer.answer_id, 160),
            userId: requireString(recentAnswer.user_id, 160),
            text: requireString(recentAnswer.text, 4000),
          };
        }),
      };
    }),
    remainingFoundationQuestions: remainingQuestions.map((candidate) => {
      const item = requireRecord(candidate);
      return {
        questionKey: requireString(item.question_key, 120),
        text: requireString(item.text, 4000),
        domain: requireLearningDomain(item.domain),
        depth: requireQuestionDepth(item.depth),
        promptAngle: requirePromptAngle(item.prompt_angle),
      };
    }),
  };
}

function parseGeneralQuestionContext(value: unknown): GeneralQuestionContext {
  const record = requireRecord(value);
  const progress = requireRecord(record.foundation_progress);
  const recentQuestions = requireArray(record.recent_questions);
  const completedCount = requireInteger(progress.completed_count, 0);
  const totalCount = requireInteger(progress.total_count, 1);

  if (completedCount > totalCount) {
    throw new TypeError('invalid general question foundation progress');
  }

  return {
    foundationProgress: {
      completedCount,
      totalCount,
    },
    recentQuestions: recentQuestions.map((question) => {
      const item = requireRecord(question);
      return {
        questionKey: requireString(item.question_key, 120),
        text: requireString(item.text, 4000),
        category: requireString(item.category, 100),
        mood: requireNullableString(item.mood, 100),
        domain: requireNullableLearningDomain(item.domain),
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

function parseFoundationProgress(
  value: Record<string, unknown>,
): CompletedQuestionContext['foundationProgress'] {
  const rawDomainProgress = requireRecord(value.domain_progress);
  const domainProgress = {} as CompletedQuestionContext[
    'foundationProgress'
  ]['domainProgress'];

  for (const domain of learningDomains) {
    const rawProgress = requireRecord(rawDomainProgress[domain]);
    domainProgress[domain] = {
      completedCount: requireInteger(rawProgress.completed_count, 0),
      totalCount: requireInteger(rawProgress.total_count, 1),
    };
  }

  const completedCount = requireInteger(value.completed_count, 0);
  const totalCount = requireInteger(value.total_count, 1);
  if (completedCount > totalCount) {
    throw new TypeError('invalid foundation progress');
  }

  return {
    completedCount,
    totalCount,
    personalizationEnabled: requireDirectBoolean(
      value.personalization_enabled,
    ),
    domainProgress,
  };
}

function requireDirectBoolean(value: unknown): boolean {
  if (typeof value !== 'boolean') {
    throw new TypeError('expected boolean');
  }
  return value;
}

function requireInteger(value: unknown, minimum: number): number {
  if (!Number.isInteger(value) || Number(value) < minimum) {
    throw new TypeError('invalid integer');
  }
  return Number(value);
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

function requireQuestionDepth(value: unknown): QuestionDepth {
  if (
    typeof value !== 'string'
    || !questionDepths.has(value as QuestionDepth)
  ) {
    throw new TypeError('invalid question depth');
  }
  return value as QuestionDepth;
}

function requireNullableQuestionDepth(value: unknown): QuestionDepth | null {
  return value === null ? null : requireQuestionDepth(value);
}

function requirePromptAngle(value: unknown): PromptAngle {
  if (
    typeof value !== 'string'
    || !promptAngles.has(value as PromptAngle)
  ) {
    throw new TypeError('invalid prompt angle');
  }
  return value as PromptAngle;
}

function requireNullablePromptAngle(value: unknown): PromptAngle | null {
  return value === null ? null : requirePromptAngle(value);
}

function requireMemoryEvidenceType(value: unknown): MemoryEvidenceType {
  if (
    typeof value !== 'string'
    || !memoryEvidenceTypes.has(value as MemoryEvidenceType)
  ) {
    throw new TypeError('invalid memory evidence type');
  }
  return value as MemoryEvidenceType;
}

function requireMemoryCandidateState(value: unknown): MemoryCandidateState {
  if (
    typeof value !== 'string'
    || !memoryCandidateStates.has(value as MemoryCandidateState)
  ) {
    throw new TypeError('invalid memory candidate state');
  }
  return value as MemoryCandidateState;
}

function requireMemoryScope(value: unknown): 'personal' | 'couple' {
  if (value !== 'personal' && value !== 'couple') {
    throw new TypeError('invalid memory scope');
  }
  return value;
}

function validateMemorySubject(
  scope: 'personal' | 'couple',
  subjectUserId: string | null,
): void {
  if (
    (scope === 'personal' && subjectUserId === null)
    || (scope === 'couple' && subjectUserId !== null)
  ) {
    throw new TypeError('invalid memory subject');
  }
}

function requireConfidence(value: unknown): number {
  if (
    typeof value !== 'number'
    || !Number.isFinite(value)
    || value < 0
    || value > 1
  ) {
    throw new TypeError('invalid memory confidence');
  }
  return value;
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
