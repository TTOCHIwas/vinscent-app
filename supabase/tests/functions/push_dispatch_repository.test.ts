import assert from 'node:assert/strict';
import test from 'node:test';

import {
  claimPushNotificationDispatch,
  completePushNotificationDelivery,
  loadRetryablePushNotificationDispatches,
  parsePushDispatchClaim,
  runPushPersistenceOperation,
} from '../../functions/_shared/push_dispatch_repository.ts';

test('retries transient push persistence errors before succeeding', async () => {
  let attempts = 0;
  const delays: number[] = [];

  const result = await runPushPersistenceOperation(
    'complete_push_notification_delivery',
    async () => {
      attempts += 1;
      return attempts < 3
        ? { data: null, error: { message: 'database unavailable' } }
        : { data: 'completed', error: null };
    },
    {
      maxAttempts: 3,
      delay: async (milliseconds) => {
        delays.push(milliseconds);
      },
    },
  );

  assert.equal(result, 'completed');
  assert.equal(attempts, 3);
  assert.deepEqual(delays, [100, 200]);
});

test('throws when push persistence remains unavailable', async () => {
  let attempts = 0;

  await assert.rejects(
    () =>
      runPushPersistenceOperation(
        'complete_push_notification_delivery',
        async () => {
          attempts += 1;
          throw new Error('connection reset');
        },
        {
          maxAttempts: 3,
          delay: async () => {},
        },
      ),
    /complete_push_notification_delivery_failed:connection reset/,
  );

  assert.equal(attempts, 3);
});

test('requires an ownership token in every push dispatch claim', () => {
  assert.throws(
    () =>
      parsePushDispatchClaim({
        claim_result: 'claimed',
        notification_type: 'recording_activity',
        source_id: 'source-id',
        receiver_user_id: 'receiver-id',
        dispatch_status: 'processing',
        claimed_at: '2026-07-22T00:00:00.000Z',
      }),
    /dispatch_claim_token_missing/,
  );

  assert.equal(
    parsePushDispatchClaim({
      claim_result: 'claimed',
      notification_type: 'recording_activity',
      source_id: 'source-id',
      receiver_user_id: 'receiver-id',
      claim_token: 'claim-token',
      dispatch_status: 'processing',
      claimed_at: '2026-07-22T00:00:00.000Z',
      attempt_count: 1,
      max_attempts: 5,
      available_at: '2026-07-22T00:00:00.000Z',
    }).claim_token,
    'claim-token',
  );
});

test('parses retry ownership metadata from a push dispatch claim', () => {
  const claim = parsePushDispatchClaim({
    claim_result: 'claimed',
    notification_type: 'recording_activity',
    source_id: 'source-id',
    receiver_user_id: 'receiver-id',
    claim_token: 'claim-token',
    dispatch_status: 'processing',
    claimed_at: '2026-07-22T00:00:00.000Z',
    attempt_count: 2,
    max_attempts: 5,
    available_at: '2026-07-22T00:01:00.000Z',
  });

  assert.equal(claim.attempt_count, 2);
  assert.equal(claim.max_attempts, 5);
});

test('persists the notification payload when claiming a dispatch', async () => {
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const supabase = {
    rpc(name: string, params: Record<string, unknown>) {
      calls.push({ name, params });
      return {
        single: async () => ({
          data: {
            claim_result: 'claimed',
            notification_type: 'calendar_event_reminder',
            source_id: 'source-id',
            receiver_user_id: 'receiver-id',
            claim_token: 'claim-token',
            dispatch_status: 'processing',
            claimed_at: '2026-07-22T00:00:00.000Z',
            attempt_count: 1,
            max_attempts: 5,
            available_at: '2026-07-22T00:00:00.000Z',
          },
          error: null,
        }),
      };
    },
  };

  await claimPushNotificationDispatch(supabase as never, {
    notificationType: 'calendar_event_reminder',
    sourceId: 'source-id',
    receiverUserId: 'receiver-id',
    title: 'Vinscent',
    body: '오늘 일정이 있어요.',
    data: {
      event_id: 'event-id',
      route: '/calendar?date=2026-07-27',
    },
    preferenceColumn: null,
    maxAttempts: 5,
  });

  assert.deepEqual(calls, [{
    name: 'claim_push_notification_dispatch',
    params: {
      requested_notification_type: 'calendar_event_reminder',
      requested_source_id: 'source-id',
      requested_receiver_user_id: 'receiver-id',
      requested_title: 'Vinscent',
      requested_body: '오늘 일정이 있어요.',
      requested_data: {
        event_id: 'event-id',
        route: '/calendar?date=2026-07-27',
      },
      requested_preference_column: null,
      requested_max_attempts: 5,
    },
  }]);
});

test('loads eligible failed dispatches for the scheduled retry worker', async () => {
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const supabase = {
    rpc(name: string, params: Record<string, unknown>) {
      calls.push({ name, params });
      return Promise.resolve({
        data: [{
          notification_type: 'calendar_event_reminder',
          source_id: 'source-id',
          receiver_user_id: 'receiver-id',
          title: 'Vinscent',
          body: '오늘 일정이 있어요.',
          data: { route: '/calendar?date=2026-07-27' },
          preference_column: null,
          attempt_count: 1,
          max_attempts: 5,
          available_at: '2026-07-22T00:01:00.000Z',
        }],
        error: null,
      });
    },
  };

  const rows = await loadRetryablePushNotificationDispatches(
    supabase as never,
    50,
  );

  assert.equal(rows.length, 1);
  assert.equal(rows[0].source_id, 'source-id');
  assert.deepEqual(calls, [{
    name: 'get_retryable_push_notification_dispatches',
    params: { requested_limit: 50 },
  }]);
});

test('completes a delivery through the atomic ownership-aware RPC', async () => {
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const supabase = {
    rpc(name: string, params: Record<string, unknown>) {
      calls.push({ name, params });
      return Promise.resolve({ data: 'completed', error: null });
    },
  };

  await completePushNotificationDelivery(supabase as never, {
    notificationType: 'recording_activity',
    sourceId: 'source-id',
    receiverUserId: 'receiver-id',
    claimToken: 'claim-token',
    targetTokenCount: 2,
    successCount: 1,
    failureCount: 1,
    status: 'partial_failure',
    errorMessage: 'one token failed',
  });

  assert.deepEqual(calls, [{
    name: 'complete_push_notification_delivery',
    params: {
      requested_notification_type: 'recording_activity',
      requested_source_id: 'source-id',
      requested_receiver_user_id: 'receiver-id',
      requested_claim_token: 'claim-token',
      requested_target_token_count: 2,
      requested_success_count: 1,
      requested_failure_count: 1,
      requested_status: 'partial_failure',
      requested_error_message: 'one token failed',
    },
  }]);
});
