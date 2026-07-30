import assert from 'node:assert/strict';
import test from 'node:test';

import {
  type ClaimedStorageCleanupAlert,
  type CompleteStorageCleanupAlertRequest,
  StorageCleanupAlertDeliveryError,
} from './storage_cleanup_alert_contract.ts';
import {
  StorageCleanupAlertProcessor,
} from './storage_cleanup_alert_processor.ts';

const alert: ClaimedStorageCleanupAlert = {
  alertId: 'alert-1',
  incidentId: 'incident-1',
  claimToken: 'claim-1',
  attemptCount: 1,
  maxAttempts: 5,
  alertKind: 'degraded',
  issueCodes: ['failed_requests'],
  failedRequestCount: 1,
  staleProcessingCount: 0,
  overduePendingCount: 0,
  cleanupCronStatus: 'healthy',
  cleanupCronLastSucceededAt: '2026-07-30T00:00:00.000Z',
  detectedAt: '2026-07-30T00:01:00.000Z',
  incidentStartedAt: '2026-07-30T00:01:00.000Z',
};

const evaluation = {
  healthStatus: 'degraded' as const,
  issueCodes: ['failed_requests'] as const,
  failedRequestCount: 1,
  staleProcessingCount: 0,
  overduePendingCount: 0,
  cleanupCronStatus: 'healthy' as const,
  cleanupCronLastSucceededAt: '2026-07-30T00:00:00.000Z',
  evaluatedAt: '2026-07-30T00:01:00.000Z',
  queuedAlertCount: 1,
};

test('evaluates health before delivering claimed alerts', async () => {
  const calls: string[] = [];
  const completions: CompleteStorageCleanupAlertRequest[] = [];
  const processor = new StorageCleanupAlertProcessor({
    workerId: 'storage-alert-worker',
    repository: {
      async evaluate() {
        calls.push('evaluate');
        return { ...evaluation, issueCodes: [...evaluation.issueCodes] };
      },
      async claim(workerId, limit) {
        calls.push('claim');
        assert.equal(workerId, 'storage-alert-worker');
        assert.equal(limit, 3);
        return [alert];
      },
      async complete(request) {
        calls.push('complete');
        completions.push(request);
        return 'delivered';
      },
    },
    delivery: {
      async deliver(received) {
        calls.push('deliver');
        assert.equal(received, alert);
      },
    },
  });

  assert.deepEqual(await processor.processBatch(3), {
    healthStatus: 'degraded',
    issueCodes: ['failed_requests'],
    queued: 1,
    claimed: 1,
    delivered: 1,
    retried: 0,
    failed: 0,
    stale: 0,
  });
  assert.deepEqual(calls, ['evaluate', 'claim', 'deliver', 'complete']);
  assert.deepEqual(completions, [{
    alertId: 'alert-1',
    claimToken: 'claim-1',
    delivered: true,
    retryable: false,
    retryDelaySeconds: 0,
  }]);
});

test('honors provider retry guidance without exposing receiver errors', async () => {
  const completions: CompleteStorageCleanupAlertRequest[] = [];
  const processor = new StorageCleanupAlertProcessor({
    workerId: 'storage-alert-worker',
    repository: {
      async evaluate() {
        return { ...evaluation, issueCodes: [...evaluation.issueCodes] };
      },
      async claim() {
        return [{ ...alert, attemptCount: 3 }];
      },
      async complete(request) {
        completions.push(request);
        return 'pending';
      },
    },
    delivery: {
      async deliver() {
        throw new StorageCleanupAlertDeliveryError(
          'discord_webhook_rate_limited',
          { retryable: true, retryAfterSeconds: 17 },
        );
      },
    },
  });

  const summary = await processor.processBatch(1);

  assert.equal(summary.retried, 1);
  assert.deepEqual(completions, [{
    alertId: 'alert-1',
    claimToken: 'claim-1',
    delivered: false,
    retryable: true,
    errorCode: 'discord_webhook_rate_limited',
    retryDelaySeconds: 17,
  }]);
});

test('stops retries when the receiver rejects the webhook', async () => {
  const completions: CompleteStorageCleanupAlertRequest[] = [];
  const processor = new StorageCleanupAlertProcessor({
    workerId: 'storage-alert-worker',
    repository: {
      async evaluate() {
        return { ...evaluation, issueCodes: [...evaluation.issueCodes] };
      },
      async claim() {
        return [alert];
      },
      async complete(request) {
        completions.push(request);
        return 'failed';
      },
    },
    delivery: {
      async deliver() {
        throw new StorageCleanupAlertDeliveryError(
          'discord_webhook_rejected',
          { retryable: false },
        );
      },
    },
  });

  const summary = await processor.processBatch(1);

  assert.equal(summary.failed, 1);
  assert.deepEqual(completions, [{
    alertId: 'alert-1',
    claimToken: 'claim-1',
    delivered: false,
    retryable: false,
    errorCode: 'discord_webhook_rejected',
    retryDelaySeconds: 60,
  }]);
});
