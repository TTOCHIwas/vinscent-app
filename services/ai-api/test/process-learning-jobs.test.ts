import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  LearningModelPort,
  LearningModelResult,
} from '../src/application/learning-model-port.ts';
import {
  AiRepositoryError,
  LearningJobProcessor,
  type ClaimedLearningJob,
  type LearningJobRepository,
  type RunFailure,
  type RunSuccess,
} from '../src/application/process-learning-jobs.ts';
import type {
  AnonymizedCompletedQuestionContext,
  CompletedQuestionContext,
  GeneralQuestionContext,
} from '../src/domain/learning-contract.ts';
import {
  GeminiOutputError,
  GeminiProviderError,
} from '../src/infrastructure/gemini-structured-generation-client.ts';

const completedContext: CompletedQuestionContext = {
  coupleId: 'couple-real-id',
  question: {
    dailyQuestionId: 'daily-question-1',
    questionId: 'question-1',
    text: 'What kind of time together feels most meaningful?',
    domain: 'personal_values',
    depth: 'light',
    promptAngle: 'preference',
  },
  answers: [
    {
      answerId: 'answer-a',
      userId: 'user-real-a',
      text: 'Quiet time at home matters to me.',
    },
    {
      answerId: 'answer-b',
      userId: 'user-real-b',
      text: 'Trying a new place together matters to me.',
    },
  ],
  foundationProgress: {
    completedCount: 1,
    totalCount: 24,
    personalizationEnabled: false,
    domainProgress: {
      personal_values: { completedCount: 1, totalCount: 4 },
      emotional_support: { completedCount: 0, totalCount: 4 },
      communication_repair: { completedCount: 0, totalCount: 4 },
      daily_life: { completedCount: 0, totalCount: 4 },
      relationship_strength: { completedCount: 0, totalCount: 4 },
      future_boundaries: { completedCount: 0, totalCount: 4 },
    },
  },
  confirmedMemories: [],
  memoryCandidates: [],
  recentFoundationQuestions: [],
  recentCompletedQuestions: [],
  remainingFoundationQuestions: [
    {
      questionKey: 'foundation_v1_personal_values_02',
      text: 'When do you feel most understood?',
      domain: 'personal_values',
      depth: 'exploratory',
      promptAngle: 'lived_experience',
    },
  ],
};

const usage = {
  inputTokenCount: 20,
  outputTokenCount: 10,
  latencyMs: 120,
};

const generalQuestionContext: GeneralQuestionContext = {
  foundationProgress: {
    completedCount: 24,
    totalCount: 24,
  },
  recentQuestions: [
    {
      questionKey: 'foundation_v1_daily_life_04',
      text: 'What part of an ordinary day do you want to share more often?',
      category: 'daily_life',
      mood: 'calm',
      domain: 'daily_life',
    },
  ],
};

test('processor handles every learning job and restores IDs only at persistence', async () => {
  const jobs: ClaimedLearningJob[] = [
    job('job-memory', 'extract_memories'),
    job('job-feedback', 'generate_feedback'),
    job('job-rank', 'select_curated_question'),
    job('job-general', 'generate_general_question'),
    job('job-personalized', 'generate_personalized_question'),
    job('job-rebuild', 'rebuild_profile', null),
  ];
  const repository = new FakeRepository(jobs);
  const seenModelContexts: AnonymizedCompletedQuestionContext[] = [];
  const seenGeneralContexts: GeneralQuestionContext[] = [];
  const model: LearningModelPort = {
    async extractMemoryCandidates(context) {
      seenModelContexts.push(context);
      return result([
        {
          memoryKey: 'partner_a_quiet_time',
          scope: 'personal',
          subjectParticipantKey: 'partner_a',
          kind: 'personal_value',
          domain: 'personal_values',
          evidenceType: 'explicit',
          sensitiveCategory: 'none',
          statement: '함께 조용히 보내는 시간을 소중하게 여겨',
          confidence: 0.8,
          evidenceAnswerIds: ['answer-a'],
        },
      ]);
    },
    async generateCoupleFeedback(context) {
      seenModelContexts.push(context);
      return result({ text: '둘의 휴식은 집과 새로운 길 사이를 오가나 봐!' });
    },
    async rankFoundationQuestions(context) {
      seenModelContexts.push(context);
      return result({
        questionKey: 'foundation_v1_personal_values_02',
        rationale: 'It fills a foundation gap.',
      });
    },
    async generateGeneralQuestion(context) {
      seenGeneralContexts.push(context);
      return result({
        questionKey: 'general_small_ritual_ab12cd34',
        text: '요즘 둘만의 작은 습관으로 만들고 싶은 건 뭐야?',
        category: 'daily_life',
        mood: 'warm',
        rationale: 'Recent questions have not covered shared rituals.',
      });
    },
    async generatePersonalizedQuestion(context) {
      seenModelContexts.push(context);
      return result({
        questionKey: 'personalized_shared_weekend_ab12cd34',
        text: 'What would make this weekend feel balanced for both?',
        category: 'personalized',
        mood: null,
        rationale: 'Their preferred ways of spending time differ.',
      });
    },
  };
  const processor = new LearningJobProcessor({
    repository,
    model,
    workerId: 'test-worker',
    provider: 'google',
    modelName: 'gemini-test',
  });

  const summary = await processor.processBatch(6);

  assert.deepEqual(summary, {
    claimed: 6,
    succeeded: 6,
    retried: 0,
    failed: 0,
  });
  assert.equal(repository.rebuildJobIds.includes('job-rebuild'), true);
  assert.equal(repository.successes.length, 5);
  assert.deepEqual(repository.successes[0]?.output, {
    memories: [
      {
        memory_key: 'partner_a_quiet_time',
        scope: 'personal',
        subject_user_id: 'user-real-a',
        kind: 'personal_value',
        learning_domain: 'personal_values',
        evidence_type: 'explicit',
        sensitive_category: 'none',
        statement: '함께 조용히 보내는 시간을 소중하게 여겨',
        confidence: 0.8,
        evidence_answer_ids: ['answer-a'],
      },
    ],
  });
  assert.deepEqual(repository.successes[1]?.output, {
    feedback_text: '둘의 휴식은 집과 새로운 길 사이를 오가나 봐!',
  });
  assert.deepEqual(repository.successes[2]?.output, {
    question_key: 'foundation_v1_personal_values_02',
    rationale: 'It fills a foundation gap.',
  });
  assert.deepEqual(repository.successes[3]?.output, {
    question_key: 'general_small_ritual_ab12cd34',
    question_text: '요즘 둘만의 작은 습관으로 만들고 싶은 건 뭐야?',
    category: 'daily_life',
    mood: 'warm',
    rationale: 'Recent questions have not covered shared rituals.',
  });
  assert.deepEqual(repository.successes[4]?.output, {
    question_key: 'personalized_shared_weekend_ab12cd34',
    question_text: 'What would make this weekend feel balanced for both?',
    category: 'personalized',
    mood: null,
    rationale: 'Their preferred ways of spending time differ.',
  });
  assert.equal(
    JSON.stringify(seenModelContexts).includes('couple-real-id'),
    false,
  );
  assert.equal(
    JSON.stringify(seenModelContexts).includes('user-real-a'),
    false,
  );
  assert.deepEqual(seenGeneralContexts, [generalQuestionContext]);
  assert.deepEqual(repository.generalContextJobIds, ['job-general']);
  assert.equal(repository.contextJobIds.includes('job-general'), false);
});

test('processor records retryable model failures and continues the batch', async () => {
  const repository = new FakeRepository([
    job('job-rate-limit', 'generate_feedback'),
    job('job-next', 'generate_feedback'),
  ]);
  let calls = 0;
  const model = modelWith({
    async generateCoupleFeedback() {
      calls += 1;
      if (calls === 1) {
        throw new GeminiProviderError({
          code: 'gemini_rate_limited',
          retryable: true,
          status: 429,
          providerStatus: 'RESOURCE_EXHAUSTED',
          providerErrorDetail: 'Quota exhausted for this project.',
          retryAfterMs: 45_000,
          latencyMs: 275,
        });
      }
      return result({ text: '둘의 휴식은 집과 새로운 길 사이를 오가나 봐!' });
    },
  });
  const processor = new LearningJobProcessor({
    repository,
    model,
    workerId: 'test-worker',
    provider: 'google',
    modelName: 'gemini-test',
  });

  const summary = await processor.processBatch(2);

  assert.deepEqual(summary, {
    claimed: 2,
    succeeded: 1,
    retried: 1,
    failed: 0,
  });
  assert.equal(repository.failures[0]?.errorCode, 'gemini_rate_limited');
  assert.equal(repository.failures[0]?.retryable, true);
  assert.equal(repository.failures[0]?.providerHttpStatus, 429);
  assert.equal(
    repository.failures[0]?.providerErrorStatus,
    'RESOURCE_EXHAUSTED',
  );
  assert.equal(
    repository.failures[0]?.providerErrorDetail,
    'Quota exhausted for this project.',
  );
  assert.equal(repository.failures[0]?.retryAfterMs, 45_000);
  assert.equal(repository.failures[0]?.usage.latencyMs, 275);
  assert.equal(repository.successes[0]?.runId, 'run-job-next');
});

test('processor regenerates shared feedback once after a contract violation', async () => {
  const repository = new FakeRepository([
    job('job-feedback-regeneration', 'generate_feedback'),
  ]);
  const rejectedFeedbacks: Array<string | null> = [];
  const invalidFeedback = '너는 시간을 소중하게 생각하는데 상대방은 아직 잘 모르겠나 봐';
  const model = modelWith({
    async generateCoupleFeedback(_context, options) {
      rejectedFeedbacks.push(options?.rejectedText ?? null);
      if (rejectedFeedbacks.length === 1) {
        return result({ text: invalidFeedback });
      }
      return result({ text: '소중한 걸 고르는 데도 시간이 조금 필요한가 봐!' });
    },
  });
  const processor = new LearningJobProcessor({
    repository,
    model,
    workerId: 'test-worker',
    provider: 'google',
    modelName: 'gemini-test',
  });

  const summary = await processor.processBatch(1);

  assert.deepEqual(summary, {
    claimed: 1,
    succeeded: 1,
    retried: 0,
    failed: 0,
  });
  assert.deepEqual(rejectedFeedbacks, [null, invalidFeedback]);
  assert.deepEqual(repository.successes[0]?.output, {
    feedback_text: '소중한 걸 고르는 데도 시간이 조금 필요한가 봐!',
  });
  assert.deepEqual(repository.successes[0]?.usage, {
    inputTokenCount: 40,
    outputTokenCount: 20,
    latencyMs: 240,
  });
});

test('processor stops after one invalid shared feedback regeneration', async () => {
  const repository = new FakeRepository([
    job('job-invalid-feedback', 'generate_feedback'),
  ]);
  let calls = 0;
  const model = modelWith({
    async generateCoupleFeedback() {
      calls += 1;
      return result({ text: '서로의 답이 다르네.' });
    },
  });
  const processor = new LearningJobProcessor({
    repository,
    model,
    workerId: 'test-worker',
    provider: 'google',
    modelName: 'gemini-test',
  });

  const summary = await processor.processBatch(1);

  assert.equal(calls, 2);
  assert.equal(summary.failed, 1);
  assert.equal(repository.failures[0]?.errorCode, 'model_contract_invalid');
  assert.equal(repository.successes.length, 0);
});

test('processor records a safe model output validation detail', async () => {
  const repository = new FakeRepository([
    job('job-invalid-memory-output', 'extract_memories'),
  ]);
  const model = modelWith({
    async extractMemoryCandidates() {
      throw new GeminiOutputError(
        undefined,
        125,
        'memory.confidence.invalid',
      );
    },
  });
  const processor = new LearningJobProcessor({
    repository,
    model,
    workerId: 'test-worker',
    provider: 'google',
    modelName: 'gemini-test',
  });

  const summary = await processor.processBatch(1);

  assert.deepEqual(summary, {
    claimed: 1,
    succeeded: 0,
    retried: 0,
    failed: 1,
  });
  assert.equal(repository.failures[0]?.errorCode, 'gemini_invalid_output');
  assert.equal(
    repository.failures[0]?.providerErrorDetail,
    'memory.confidence.invalid',
  );
  assert.equal(repository.failures[0]?.usage.latencyMs, 125);
});

test('processor terminally rejects a recommendation outside candidates', async () => {
  const repository = new FakeRepository([
    job('job-invalid-rank', 'select_curated_question'),
  ]);
  const model = modelWith({
    async rankFoundationQuestions() {
      return result({
        questionKey: 'not-an-allowed-question',
        rationale: 'Invalid choice.',
      });
    },
  });
  const processor = new LearningJobProcessor({
    repository,
    model,
    workerId: 'test-worker',
    provider: 'google',
    modelName: 'gemini-test',
  });

  const summary = await processor.processBatch(1);

  assert.equal(summary.failed, 1);
  assert.equal(repository.failures[0]?.errorCode, 'model_contract_invalid');
  assert.equal(repository.failures[0]?.retryable, false);
  assert.equal(repository.successes.length, 0);
});

test('processor reports repository failures before a run without leaking details', async () => {
  const repository = new FakeRepository([
    job('job-context-failure', 'generate_feedback'),
  ]);
  repository.contextError = new AiRepositoryError({
    code: 'ai_context_unavailable',
    retryable: true,
  });
  const processor = new LearningJobProcessor({
    repository,
    model: modelWith({}),
    workerId: 'test-worker',
    provider: 'google',
    modelName: 'gemini-test',
  });

  const summary = await processor.processBatch(1);

  assert.equal(summary.retried, 1);
  assert.deepEqual(repository.claimFailures, [
    {
      jobId: 'job-context-failure',
      errorCode: 'ai_context_unavailable',
      retryable: true,
    },
  ]);
});

class FakeRepository implements LearningJobRepository {
  readonly #jobs: ClaimedLearningJob[];
  readonly successes: RunSuccess[] = [];
  readonly failures: RunFailure[] = [];
  readonly rebuildJobIds: string[] = [];
  readonly contextJobIds: string[] = [];
  readonly generalContextJobIds: string[] = [];
  readonly claimFailures: Array<{
    jobId: string;
    errorCode: string;
    retryable: boolean;
  }> = [];
  contextError: Error | null = null;

  constructor(jobs: ClaimedLearningJob[]) {
    this.#jobs = jobs;
  }

  async claimJobs(_workerId: string, limit: number) {
    return this.#jobs.slice(0, limit);
  }

  async loadContext(jobId: string) {
    this.contextJobIds.push(jobId);
    if (this.contextError) {
      throw this.contextError;
    }
    return completedContext;
  }

  async loadGeneralQuestionContext(jobId: string) {
    this.generalContextJobIds.push(jobId);
    return generalQuestionContext;
  }

  async startRun(job: ClaimedLearningJob) {
    return `run-${job.jobId}`;
  }

  async succeedRun(success: RunSuccess) {
    this.successes.push(success);
    return true;
  }

  async failRun(failure: RunFailure) {
    this.failures.push(failure);
    return true;
  }

  async failClaimedJob(
    jobId: string,
    errorCode: string,
    retryable: boolean,
  ) {
    this.claimFailures.push({ jobId, errorCode, retryable });
    return true;
  }

  async expandRebuild(jobId: string) {
    this.rebuildJobIds.push(jobId);
    return true;
  }
}

function job(
  jobId: string,
  jobType: ClaimedLearningJob['jobType'],
  dailyQuestionId = 'daily-question-1' as string | null,
): ClaimedLearningJob {
  return {
    jobId,
    coupleId: 'couple-real-id',
    dailyQuestionId,
    jobType,
    attempt: 1,
    leaseExpiresAt: '2026-07-20T12:00:00.000Z',
  };
}

function result<T>(value: T): LearningModelResult<T> {
  return { value, usage };
}

function modelWith(
  overrides: Partial<LearningModelPort>,
): LearningModelPort {
  return {
    async rankFoundationQuestions() {
      return result({
        questionKey: 'foundation_v1_personal_values_02',
        rationale: 'Default rationale.',
      });
    },
    async extractMemoryCandidates() {
      return result([]);
    },
    async generateCoupleFeedback() {
      return result({ text: '둘의 답이 작은 장면 하나를 만들었네!' });
    },
    async generateGeneralQuestion() {
      return result({
        questionKey: 'general_default_question_ab12cd34',
        text: 'Default general question?',
        category: 'daily_life',
        mood: null,
        rationale: 'Default rationale.',
      });
    },
    async generatePersonalizedQuestion() {
      return result({
        questionKey: 'personalized_default_question_ab12cd34',
        text: 'Default question?',
        category: 'personalized',
        mood: null,
        rationale: 'Default rationale.',
      });
    },
    ...overrides,
  };
}
