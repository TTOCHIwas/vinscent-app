import assert from 'node:assert/strict';
import test from 'node:test';

import { AiRepositoryError } from '../src/application/process-learning-jobs.ts';
import {
  SupabaseLearningJobRepository,
  type SupabaseRpcClient,
} from '../src/infrastructure/supabase-learning-job-repository.ts';

test('repository maps claimed jobs and worker context', async () => {
  const client = new FakeRpcClient({
    claim_ai_processing_jobs: {
      data: [
        {
          job_id: 'job-1',
          job_couple_id: 'couple-1',
          job_daily_question_id: 'daily-1',
          job_type: 'generate_feedback',
          job_attempt: 2,
          job_lease_expires_at: '2026-07-20T12:00:00.000Z',
        },
      ],
      error: null,
    },
    get_ai_processing_job_context: {
      data: {
        couple_id: 'couple-1',
        question: {
          daily_question_id: 'daily-1',
          question_id: 'question-1',
          text: 'Question?',
          domain: 'personal_values',
          depth: 'light',
          prompt_angle: 'preference',
        },
        answers: [
          { answer_id: 'answer-a', user_id: 'user-a', text: 'Answer A' },
          { answer_id: 'answer-b', user_id: 'user-b', text: 'Answer B' },
        ],
        foundation_progress: {
          completed_count: 24,
          total_count: 24,
          personalization_enabled: true,
          domain_progress: {
            personal_values: { completed_count: 4, total_count: 4 },
            emotional_support: { completed_count: 4, total_count: 4 },
            communication_repair: { completed_count: 4, total_count: 4 },
            daily_life: { completed_count: 4, total_count: 4 },
            relationship_strength: { completed_count: 4, total_count: 4 },
            future_boundaries: { completed_count: 4, total_count: 4 },
          },
        },
        confirmed_memories: [
          {
            memory_key: 'shared_walks',
            scope: 'couple',
            subject_user_id: null,
            kind: 'shared_preference',
            learning_domain: 'daily_life',
            evidence_type: 'explicit',
            statement: 'They enjoy walking together.',
            confidence: 0.9,
          },
        ],
        memory_candidates: [],
        recent_foundation_questions: [],
        recent_completed_questions: [],
        remaining_foundation_questions: [
          {
            question_key: 'foundation_v1_personal_values_02',
            text: 'Next question?',
            domain: 'personal_values',
            depth: 'exploratory',
            prompt_angle: 'lived_experience',
          },
        ],
      },
      error: null,
    },
  });
  const repository = new SupabaseLearningJobRepository(client);

  const jobs = await repository.claimJobs('edge-worker', 3);
  const context = await repository.loadContext('job-1');

  assert.deepEqual(jobs, [
    {
      jobId: 'job-1',
      coupleId: 'couple-1',
      dailyQuestionId: 'daily-1',
      jobType: 'generate_feedback',
      attempt: 2,
      leaseExpiresAt: '2026-07-20T12:00:00.000Z',
    },
  ]);
  assert.equal(context.answers[0]?.userId, 'user-a');
  assert.equal(context.confirmedMemories[0]?.scope, 'couple');
  assert.equal(context.foundationProgress.personalizationEnabled, true);
  assert.equal(context.confirmedMemories[0]?.domain, 'daily_life');
  assert.equal(
    context.remainingFoundationQuestions[0]?.depth,
    'exploratory',
  );
  assert.equal(
    context.remainingFoundationQuestions[0]?.questionKey,
    'foundation_v1_personal_values_02',
  );
  assert.deepEqual(client.calls[0], {
    name: 'claim_ai_processing_jobs',
    params: { requested_worker: 'edge-worker', requested_limit: 3 },
  });
});

test('repository sends run lifecycle values to exact RPC arguments', async () => {
  const client = new FakeRpcClient({
    start_ai_processing_run: { data: 'run-1', error: null },
    succeed_ai_processing_run: { data: true, error: null },
    fail_ai_processing_run_with_diagnostics_v2: { data: true, error: null },
    complete_ai_processing_job: { data: true, error: null },
    expand_ai_rebuild_profile_job: { data: true, error: null },
  });
  const repository = new SupabaseLearningJobRepository(client);

  const runId = await repository.startRun(
    {
      jobId: 'job-1',
      coupleId: 'couple-1',
      dailyQuestionId: 'daily-1',
      jobType: 'generate_feedback',
      attempt: 1,
      leaseExpiresAt: '2026-07-20T12:00:00.000Z',
    },
    'google',
    'gemini-test',
    'feedback-v1',
  );
  await repository.succeedRun({
    runId,
    output: { feedback_text: 'Feedback' },
    usage: {
      inputTokenCount: 10,
      outputTokenCount: 5,
      latencyMs: 100,
    },
  });
  await repository.failRun({
    runId,
    errorCode: 'gemini_rate_limited',
    safetyStatus: 'error',
    retryable: true,
    providerHttpStatus: 429,
    providerErrorStatus: 'RESOURCE_EXHAUSTED',
    providerErrorDetail: 'Quota exhausted for this project.',
    retryAfterMs: 45_000,
    usage: {
      inputTokenCount: null,
      outputTokenCount: null,
      latencyMs: 200,
    },
  });
  await repository.failClaimedJob('job-2', 'invalid_context', false);
  await repository.expandRebuild('job-3');

  assert.deepEqual(client.calls[1], {
    name: 'succeed_ai_processing_run',
    params: {
      requested_run_id: 'run-1',
      requested_output: { feedback_text: 'Feedback' },
      requested_input_token_count: 10,
      requested_output_token_count: 5,
      requested_latency_ms: 100,
    },
  });
  assert.deepEqual(client.calls[2], {
    name: 'fail_ai_processing_run_with_diagnostics_v2',
    params: {
      requested_run_id: 'run-1',
      requested_error_code: 'gemini_rate_limited',
      requested_safety_status: 'error',
      requested_retryable: true,
      requested_input_token_count: null,
      requested_output_token_count: null,
      requested_latency_ms: 200,
      requested_provider_http_status: 429,
      requested_provider_error_status: 'RESOURCE_EXHAUSTED',
      requested_provider_error_detail: 'Quota exhausted for this project.',
      requested_retry_after_ms: 45_000,
    },
  });
  assert.deepEqual(client.calls[3], {
    name: 'complete_ai_processing_job',
    params: {
      requested_job_id: 'job-2',
      requested_result: 'cancelled',
      requested_error: 'invalid_context',
    },
  });
});

test('repository rejects malformed context as terminal contract error', async () => {
  const repository = new SupabaseLearningJobRepository(new FakeRpcClient({
    get_ai_processing_job_context: {
      data: { couple_id: 'couple-1', answers: [] },
      error: null,
    },
  }));

  await assert.rejects(
    () => repository.loadContext('job-1'),
    (error: unknown) => {
      assert.ok(error instanceof AiRepositoryError);
      assert.equal(error.code, 'ai_context_invalid');
      assert.equal(error.retryable, false);
      return true;
    },
  );
});

test('repository sanitizes RPC failures and preserves retry classification', async () => {
  const repository = new SupabaseLearningJobRepository(new FakeRpcClient({
    get_ai_processing_job_context: {
      data: null,
      error: {
        code: 'P0001',
        message: 'invalid_ai_job_context with private answer details',
      },
    },
  }));

  await assert.rejects(
    () => repository.loadContext('job-1'),
    (error: unknown) => {
      assert.ok(error instanceof AiRepositoryError);
      assert.equal(error.code, 'ai_context_unavailable');
      assert.equal(error.retryable, false);
      assert.equal(error.message.includes('private answer details'), false);
      return true;
    },
  );
});

class FakeRpcClient implements SupabaseRpcClient {
  readonly #responses: Record<string, { data: unknown; error: unknown }>;
  readonly calls: Array<{
    name: string;
    params: Record<string, unknown> | undefined;
  }> = [];

  constructor(responses: Record<string, { data: unknown; error: unknown }>) {
    this.#responses = responses;
  }

  async rpc(name: string, params?: Record<string, unknown>) {
    this.calls.push({ name, params });
    return this.#responses[name] ?? { data: null, error: null };
  }
}
