import assert from 'node:assert/strict';
import test from 'node:test';

import {
  type SafetyModerationRpcClient,
  SupabaseSafetyModerationAlertRepository,
} from './safety_moderation_alert_repository.ts';

test('claims alerts without retaining report content or user identifiers', async () => {
  const calls: Array<[string, Record<string, unknown> | undefined]> = [];
  const client: SafetyModerationRpcClient = {
    async rpc(name, params) {
      calls.push([name, params]);
      return {
        error: null,
        data: [{
          report_id: 'report-1',
          claim_token: 'claim-1',
          attempt_count: 1,
          max_attempts: 5,
          reporter_user_id: 'reporter-private',
          reported_user_id: 'reported-private',
          couple_id: 'couple-private',
          target_type: 'recording',
          target_id: 'target-private',
          reason: 'inappropriate',
          details: 'private report details',
          content_snapshot: 'private content snapshot',
          report_created_at: '2026-07-29T00:00:00.000Z',
        }],
      };
    },
  };
  const repository = new SupabaseSafetyModerationAlertRepository(client);

  const claimed = await repository.claim('worker-1', 5);

  assert.deepEqual(calls, [[
    'claim_safety_moderation_alerts',
    {
      requested_worker_id: 'worker-1',
      requested_limit: 5,
    },
  ]]);
  assert.deepEqual(claimed, [{
    reportId: 'report-1',
    claimToken: 'claim-1',
    attemptCount: 1,
    maxAttempts: 5,
    targetType: 'recording',
    reason: 'inappropriate',
    hasDetails: true,
    hasContentSnapshot: true,
    reportCreatedAt: '2026-07-29T00:00:00.000Z',
  }]);
  const serialized = JSON.stringify(claimed);
  assert.equal(serialized.includes('reporter-private'), false);
  assert.equal(serialized.includes('private report details'), false);
  assert.equal(serialized.includes('private content snapshot'), false);
});

test('completes alerts through the ownership-aware RPC', async () => {
  const calls: Array<[string, Record<string, unknown> | undefined]> = [];
  const client: SafetyModerationRpcClient = {
    async rpc(name, params) {
      calls.push([name, params]);
      return { data: 'pending', error: null };
    },
  };
  const repository = new SupabaseSafetyModerationAlertRepository(client);

  const status = await repository.complete({
    reportId: 'report-1',
    claimToken: 'claim-1',
    delivered: false,
    errorCode: 'moderation_webhook_unavailable',
    retryDelaySeconds: 60,
  });

  assert.equal(status, 'pending');
  assert.deepEqual(calls, [[
    'complete_safety_moderation_alert',
    {
      requested_report_id: 'report-1',
      requested_claim_token: 'claim-1',
      requested_delivered: false,
      requested_error: 'moderation_webhook_unavailable',
      requested_retry_delay_seconds: 60,
    },
  ]]);
});
