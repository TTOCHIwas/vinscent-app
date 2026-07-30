import assert from 'node:assert/strict';
import test from 'node:test';

import {
  type StorageCleanupAlertRpcClient,
  SupabaseStorageCleanupAlertRepository,
} from './storage_cleanup_alert_repository.ts';

test('maps health, claim, and completion RPC contracts', async () => {
  const calls: Array<[string, Record<string, unknown> | undefined]> = [];
  const client: StorageCleanupAlertRpcClient = {
    async rpc(name, params) {
      calls.push([name, params]);
      if (name === 'evaluate_storage_cleanup_health') {
        return {
          error: null,
          data: [{
            health_status: 'degraded',
            issue_codes: ['failed_requests'],
            failed_request_count: 2,
            stale_processing_count: 0,
            overdue_pending_count: 0,
            cleanup_cron_status: 'healthy',
            cleanup_cron_last_succeeded_at:
              '2026-07-30T00:00:00.000Z',
            evaluated_at: '2026-07-30T00:01:00.000Z',
            queued_alert_count: 1,
          }],
        };
      }
      if (name === 'claim_storage_cleanup_operational_alerts') {
        return {
          error: null,
          data: [{
            alert_id: 'alert-1',
            incident_id: 'incident-1',
            claim_token: 'claim-private',
            attempt_count: 1,
            max_attempts: 5,
            alert_kind: 'degraded',
            issue_codes: ['failed_requests'],
            failed_request_count: 2,
            stale_processing_count: 0,
            overdue_pending_count: 0,
            cleanup_cron_status: 'healthy',
            cleanup_cron_last_succeeded_at:
              '2026-07-30T00:00:00.000Z',
            detected_at: '2026-07-30T00:01:00.000Z',
            incident_started_at: '2026-07-30T00:01:00.000Z',
          }],
        };
      }
      return { data: 'pending', error: null };
    },
  };
  const repository = new SupabaseStorageCleanupAlertRepository(client);

  assert.deepEqual(await repository.evaluate(), {
    healthStatus: 'degraded',
    issueCodes: ['failed_requests'],
    failedRequestCount: 2,
    staleProcessingCount: 0,
    overduePendingCount: 0,
    cleanupCronStatus: 'healthy',
    cleanupCronLastSucceededAt: '2026-07-30T00:00:00.000Z',
    evaluatedAt: '2026-07-30T00:01:00.000Z',
    queuedAlertCount: 1,
  });

  const claimed = await repository.claim('worker-1', 5);
  assert.deepEqual(claimed, [{
    alertId: 'alert-1',
    incidentId: 'incident-1',
    claimToken: 'claim-private',
    attemptCount: 1,
    maxAttempts: 5,
    alertKind: 'degraded',
    issueCodes: ['failed_requests'],
    failedRequestCount: 2,
    staleProcessingCount: 0,
    overduePendingCount: 0,
    cleanupCronStatus: 'healthy',
    cleanupCronLastSucceededAt: '2026-07-30T00:00:00.000Z',
    detectedAt: '2026-07-30T00:01:00.000Z',
    incidentStartedAt: '2026-07-30T00:01:00.000Z',
  }]);

  assert.equal(await repository.complete({
    alertId: 'alert-1',
    claimToken: 'claim-private',
    delivered: false,
    retryable: true,
    errorCode: 'discord_webhook_unavailable',
    retryDelaySeconds: 60,
  }), 'pending');

  assert.deepEqual(calls, [
    ['evaluate_storage_cleanup_health', undefined],
    [
      'claim_storage_cleanup_operational_alerts',
      {
        requested_worker_id: 'worker-1',
        requested_limit: 5,
      },
    ],
    [
      'complete_storage_cleanup_operational_alert',
      {
        requested_alert_id: 'alert-1',
        requested_claim_token: 'claim-private',
        requested_delivered: false,
        requested_retryable: true,
        requested_error: 'discord_webhook_unavailable',
        requested_retry_delay_seconds: 60,
      },
    ],
  ]);
});

test('rejects unbounded issue codes returned by the database', async () => {
  const repository = new SupabaseStorageCleanupAlertRepository({
    async rpc() {
      return {
        error: null,
        data: [{
          health_status: 'degraded',
          issue_codes: ['private/object/path'],
          failed_request_count: 1,
          stale_processing_count: 0,
          overdue_pending_count: 0,
          cleanup_cron_status: 'healthy',
          cleanup_cron_last_succeeded_at: null,
          evaluated_at: '2026-07-30T00:01:00.000Z',
          queued_alert_count: 1,
        }],
      };
    },
  });

  await assert.rejects(
    () => repository.evaluate(),
    /invalid_issue_codes/,
  );
});
