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
} from '../src/domain/learning-contract.ts';
import { GeminiProviderError } from '../src/infrastructure/gemini-interactions-client.ts';

const completedContext: CompletedQuestionContext = {
  coupleId: 'couple-real-id',
  question: {
    dailyQuestionId: 'daily-question-1',
    questionId: 'question-1',
    text: 'What kind of time together feels most meaningful?',
    domain: 'personal_values',
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
  confirmedMemories: [],
  remainingFoundationQuestions: [
    {
      questionKey: 'foundation_v1_personal_values_02',
      text: 'When do you feel most understood?',
      domain: 'personal_values',
    },
  ],
};

const usage = {
  inputTokenCount: 20,
  outputTokenCount: 10,
  latencyMs: 120,
};

test('processor handles every learning job and restores IDs only at persistence', async () => {
  const jobs: ClaimedLearningJob[] = [
    job('job-memory', 'extract_memories'),
    job('job-feedback', 'generate_feedback'),
    job('job-rank', 'select_curated_question'),
    job('job-personalized', 'generate_personalized_question'),
    job('job-rebuild', 'rebuild_profile', null),
  ];
  const repository = new FakeRepository(jobs);
  const seenModelContexts: AnonymizedCompletedQuestionContext[] = [];
  const model: LearningModelPort = {
    async extractMemoryCandidates(context) {
      seenModelContexts.push(context);
      return result([
        {
          memoryKey: 'partner_a_quiet_time',
          scope: 'personal',
          subjectParticipantKey: 'partner_a',
          kind: 'personal_value',
          statement: 'Partner A values quiet time together.',
          confidence: 0.8,
          evidenceAnswerIds: ['answer-a'],
        },
      ]);
    },
    async generateCoupleFeedback(context) {
      seenModelContexts.push(context);
      return result({ text: 'You can make room for both preferences.' });
    },
    async rankFoundationQuestions(context) {
      seenModelContexts.push(context);
      return result({
        questionKey: 'foundation_v1_personal_values_02',
        rationale: 'It fills a foundation gap.',
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

  const summary = await processor.processBatch(5);

  assert.deepEqual(summary, {
    claimed: 5,
    succeeded: 5,
    retried: 0,
    failed: 0,
  });
  assert.equal(repository.rebuildJobIds.includes('job-rebuild'), true);
  assert.equal(repository.successes.length, 4);
  assert.deepEqual(repository.successes[0]?.output, {
    memories: [
      {
        memory_key: 'partner_a_quiet_time',
        scope: 'personal',
        subject_user_id: 'user-real-a',
        kind: 'personal_value',
        statement: 'Partner A values quiet time together.',
        confidence: 0.8,
        evidence_answer_ids: ['answer-a'],
      },
    ],
  });
  assert.deepEqual(repository.successes[1]?.output, {
    feedback_text: 'You can make room for both preferences.',
  });
  assert.deepEqual(repository.successes[2]?.output, {
    question_key: 'foundation_v1_personal_values_02',
    rationale: 'It fills a foundation gap.',
  });
  assert.deepEqual(repository.successes[3]?.output, {
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
        });
      }
      return result({ text: 'The second job succeeds.' });
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
  assert.equal(repository.successes[0]?.runId, 'run-job-next');
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

  async loadContext(_jobId: string) {
    if (this.contextError) {
      throw this.contextError;
    }
    return completedContext;
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
      return result({ text: 'Default feedback.' });
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
