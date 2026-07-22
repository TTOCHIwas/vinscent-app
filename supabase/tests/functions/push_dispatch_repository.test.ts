import assert from 'node:assert/strict';
import test from 'node:test';

import {
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
    () => runPushPersistenceOperation(
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
    () => parsePushDispatchClaim({
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
    }).claim_token,
    'claim-token',
  );
});
