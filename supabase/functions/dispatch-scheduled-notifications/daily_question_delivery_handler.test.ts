import assert from 'node:assert/strict';
import test from 'node:test';

import { loadDueDailyQuestionDeliveryJobs } from './daily_question_delivery_handler.ts';

test('loads and maps due daily question delivery jobs', async () => {
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const supabase = {
    rpc(name: string, params: Record<string, unknown>) {
      calls.push({ name, params });
      return Promise.resolve({
        data: [{
          daily_question_id: 'question-id',
          couple_id: 'couple-id',
          receiver_user_id: 'receiver-id',
          assigned_date: '2026-09-09',
        }],
        error: null,
      });
    },
  };
  const runAt = new Date('2026-09-09T09:00:00.000Z');

  const jobs = await loadDueDailyQuestionDeliveryJobs(
    supabase as never,
    runAt,
  );

  assert.deepEqual(jobs, [{
    dailyQuestionId: 'question-id',
    coupleId: 'couple-id',
    receiverUserId: 'receiver-id',
    assignedDate: '2026-09-09',
  }]);
  assert.deepEqual(calls, [{
    name: 'assign_due_daily_questions',
    params: {
      requested_run_at: '2026-09-09T09:00:00.000Z',
      requested_limit: 100,
    },
  }]);
});

test('returns no daily question jobs when the RPC returns no rows', async () => {
  const supabase = {
    rpc() {
      return Promise.resolve({ data: null, error: null });
    },
  };

  const jobs = await loadDueDailyQuestionDeliveryJobs(
    supabase as never,
    new Date('2026-09-09T09:00:00.000Z'),
  );

  assert.deepEqual(jobs, []);
});

test('surfaces daily question assignment RPC failures', async () => {
  const supabase = {
    rpc() {
      return Promise.resolve({
        data: null,
        error: { message: 'database unavailable' },
      });
    },
  };

  await assert.rejects(
    () => loadDueDailyQuestionDeliveryJobs(
      supabase as never,
      new Date('2026-09-09T09:00:00.000Z'),
    ),
    /daily_question_assignment_failed:database unavailable/,
  );
});
