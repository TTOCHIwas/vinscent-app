import assert from 'node:assert/strict';
import test from 'node:test';

import {
  type ClaimedSafetyModerationAlert,
  type CompleteSafetyModerationAlertRequest,
  SafetyModerationDeliveryError,
  type SafetyModerationAlertCompletionStatus,
} from './safety_moderation_alert_contract.ts';
import {
  SafetyModerationAlertProcessor,
} from './process_safety_moderation_alerts.ts';

const alert: ClaimedSafetyModerationAlert = {
  reportId: 'report-1',
  claimToken: 'claim-1',
  attemptCount: 1,
  maxAttempts: 5,
  targetType: 'story_card',
  reason: 'inappropriate',
  hasDetails: true,
  hasContentSnapshot: true,
  reportCreatedAt: '2026-07-29T00:00:00.000Z',
};

test('delivers claimed alerts and completes their ownership token', async () => {
  const completions: CompleteSafetyModerationAlertRequest[] = [];
  const processor = new SafetyModerationAlertProcessor({
    workerId: 'worker-1',
    repository: {
      async claim(workerId, limit) {
        assert.equal(workerId, 'worker-1');
        assert.equal(limit, 3);
        return [alert];
      },
      async complete(request) {
        completions.push(request);
        return 'delivered';
      },
    },
    delivery: {
      async deliver(received) {
        assert.equal(received, alert);
      },
    },
  });

  assert.deepEqual(await processor.processBatch(3), {
    claimed: 1,
    delivered: 1,
    retried: 0,
    failed: 0,
    stale: 0,
  });
  assert.deepEqual(completions, [{
    reportId: 'report-1',
    claimToken: 'claim-1',
    delivered: true,
    retryDelaySeconds: 0,
  }]);
});

test('records stable delivery errors and exponential retry delays', async () => {
  const completions: CompleteSafetyModerationAlertRequest[] = [];
  const processor = new SafetyModerationAlertProcessor({
    workerId: 'worker-1',
    repository: {
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
        throw new SafetyModerationDeliveryError(
          'moderation_webhook_rate_limited',
        );
      },
    },
  });

  assert.deepEqual(await processor.processBatch(1), {
    claimed: 1,
    delivered: 0,
    retried: 1,
    failed: 0,
    stale: 0,
  });
  assert.deepEqual(completions, [{
    reportId: 'report-1',
    claimToken: 'claim-1',
    delivered: false,
    errorCode: 'moderation_webhook_rate_limited',
    retryDelaySeconds: 240,
  }]);
});

test('counts terminal and stale completion outcomes independently', async () => {
  const statuses: SafetyModerationAlertCompletionStatus[] = [
    'failed',
    'stale',
  ];
  const processor = new SafetyModerationAlertProcessor({
    workerId: 'worker-1',
    repository: {
      async claim() {
        return [
          alert,
          { ...alert, reportId: 'report-2', claimToken: 'claim-2' },
        ];
      },
      async complete() {
        return statuses.shift() ?? 'failed';
      },
    },
    delivery: {
      async deliver() {
        throw new Error('private webhook response');
      },
    },
  });

  assert.deepEqual(await processor.processBatch(2), {
    claimed: 2,
    delivered: 0,
    retried: 0,
    failed: 1,
    stale: 1,
  });
});
