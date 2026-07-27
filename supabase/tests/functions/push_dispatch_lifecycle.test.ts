import assert from 'node:assert/strict';
import test from 'node:test';

import {
  finalizeExhaustedPushNotificationDispatches,
} from '../../functions/_shared/push_dispatch_repository.ts';
import {
  sendPushNotification,
} from '../../functions/_shared/push.ts';

test('finalizes exhausted push dispatches before loading retries', async () => {
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const supabase = {
    rpc(name: string, params: Record<string, unknown>) {
      calls.push({ name, params });
      return Promise.resolve({ data: 2, error: null });
    },
  };

  const count = await finalizeExhaustedPushNotificationDispatches(
    supabase as never,
    100,
  );

  assert.equal(count, 2);
  assert.deepEqual(calls, [{
    name: 'finalize_exhausted_push_notification_dispatches',
    params: { requested_limit: 100 },
  }]);
});

test('rejects an invalid exhausted dispatch finalization result', async () => {
  const supabase = {
    rpc() {
      return Promise.resolve({ data: null, error: null });
    },
  };

  await assert.rejects(
    () =>
      finalizeExhaustedPushNotificationDispatches(
        supabase as never,
        100,
      ),
    /exhausted_push_dispatch_finalize_result_invalid/,
  );
});

test('finalizes a claimed dispatch when notification preflight fails', async () => {
  const rpcCalls: Array<{
    name: string;
    params: Record<string, unknown>;
  }> = [];
  const supabase = {
    rpc(name: string, params: Record<string, unknown>) {
      rpcCalls.push({ name, params });
      if (name === 'claim_push_notification_dispatch') {
        return {
          single: async () => ({
            data: {
              claim_result: 'claimed',
              notification_type: 'unanswered_reminder',
              source_id: 'source-id',
              receiver_user_id: 'receiver-id',
              claim_token: 'claim-token',
              dispatch_status: 'processing',
              claimed_at: '2026-07-27T00:00:00.000Z',
              attempt_count: 1,
              max_attempts: 5,
              available_at: '2026-07-27T00:00:00.000Z',
            },
            error: null,
          }),
        };
      }

      return Promise.resolve({ data: 'completed', error: null });
    },
    from(table: string) {
      assert.equal(table, 'user_notification_preferences');
      const query = {
        select() {
          return query;
        },
        eq() {
          return query;
        },
        maybeSingle() {
          return Promise.resolve({
            data: null,
            error: { message: 'preference database unavailable' },
          });
        },
      };
      return query;
    },
  };

  await assert.rejects(
    () =>
      sendPushNotification({
        supabase: supabase as never,
        notificationType: 'unanswered_reminder',
        sourceId: 'source-id',
        receiverUserId: 'receiver-id',
        title: 'Vinscent',
        body: '답변을 기다리고 있어요',
        data: {},
        preferenceColumn: 'reminder_enabled',
        accessToken: 'access-token',
      }),
    /notification_preference_query_failed:preference database unavailable/,
  );

  assert.equal(rpcCalls.length, 2);
  assert.equal(
    rpcCalls[1].name,
    'complete_push_notification_delivery',
  );
  assert.equal(rpcCalls[1].params.requested_status, 'failed');
  assert.match(
    String(rpcCalls[1].params.requested_error_message),
    /push_preflight_failed:notification_preference_query_failed/,
  );
});
