import assert from 'node:assert/strict';
import test from 'node:test';

import {
  finalizeExpiredStoryCards,
  finalizeExpiredStoryCardsSafely,
} from './story_card_rollover_handler.ts';

test('finalizes expired story cards with the bounded rollover RPC', async () => {
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const supabase = {
    rpc(name: string, params: Record<string, unknown>) {
      calls.push({ name, params });
      return Promise.resolve({ data: 3, error: null });
    },
  };
  const runAt = new Date('2026-09-09T15:00:00.000Z');

  const finalizedCount = await finalizeExpiredStoryCards(
    supabase as never,
    runAt,
  );

  assert.equal(finalizedCount, 3);
  assert.deepEqual(calls, [{
    name: 'finalize_expired_story_cards',
    params: {
      requested_run_at: '2026-09-09T15:00:00.000Z',
      requested_limit: 200,
    },
  }]);
});

test('normalizes an empty rollover result to zero', async () => {
  const supabase = {
    rpc() {
      return Promise.resolve({ data: null, error: null });
    },
  };

  const finalizedCount = await finalizeExpiredStoryCards(
    supabase as never,
    new Date('2026-09-09T15:00:00.000Z'),
  );

  assert.equal(finalizedCount, 0);
});

test('surfaces story card rollover RPC failures', async () => {
  const supabase = {
    rpc() {
      return Promise.resolve({
        data: null,
        error: { message: 'database unavailable' },
      });
    },
  };

  await assert.rejects(
    () => finalizeExpiredStoryCards(
      supabase as never,
      new Date('2026-09-09T15:00:00.000Z'),
    ),
    /story_card_rollover_failed:database unavailable/,
  );
});

test('isolates story card rollover failures from scheduled notifications', async () => {
  const supabase = {
    rpc() {
      return Promise.resolve({
        data: null,
        error: { message: 'database unavailable' },
      });
    },
  };
  const reportedErrors: unknown[] = [];

  const result = await finalizeExpiredStoryCardsSafely(
    supabase as never,
    new Date('2026-09-09T15:00:00.000Z'),
    (error) => reportedErrors.push(error),
  );

  assert.deepEqual(result, {
    status: 'failed',
    finalizedCount: 0,
  });
  assert.equal(reportedErrors.length, 1);
});

test('reports successful story card rollover work', async () => {
  const supabase = {
    rpc() {
      return Promise.resolve({ data: 2, error: null });
    },
  };

  const result = await finalizeExpiredStoryCardsSafely(
    supabase as never,
    new Date('2026-09-09T15:00:00.000Z'),
  );

  assert.deepEqual(result, {
    status: 'ok',
    finalizedCount: 2,
  });
});
