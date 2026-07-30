import {
  type ClaimedStorageCleanupAlert,
  type StorageCleanupAlertBatchSummary,
  type StorageCleanupAlertCompletionStatus,
  type StorageCleanupAlertDelivery,
  StorageCleanupAlertDeliveryError,
  type StorageCleanupAlertRepository,
} from './storage_cleanup_alert_contract.ts';

type StorageCleanupAlertProcessorOptions = {
  repository: StorageCleanupAlertRepository;
  delivery: StorageCleanupAlertDelivery;
  workerId: string;
  onError?: (error: unknown) => void;
};

export class StorageCleanupAlertProcessor {
  readonly #repository: StorageCleanupAlertRepository;
  readonly #delivery: StorageCleanupAlertDelivery;
  readonly #workerId: string;
  readonly #onError: (error: unknown) => void;

  constructor(options: StorageCleanupAlertProcessorOptions) {
    this.#repository = options.repository;
    this.#delivery = options.delivery;
    this.#workerId = options.workerId.trim();
    if (this.#workerId.length === 0 || this.#workerId.length > 120) {
      throw new TypeError('storage cleanup alert worker id is invalid');
    }
    this.#onError = options.onError ?? logSafeError;
  }

  async processBatch(
    limit: number,
  ): Promise<StorageCleanupAlertBatchSummary> {
    const evaluation = await this.#repository.evaluate();
    const alerts = await this.#repository.claim(this.#workerId, limit);
    const summary: StorageCleanupAlertBatchSummary = {
      healthStatus: evaluation.healthStatus,
      issueCodes: evaluation.issueCodes,
      queued: evaluation.queuedAlertCount,
      claimed: alerts.length,
      delivered: 0,
      retried: 0,
      failed: 0,
      stale: 0,
    };

    for (const alert of alerts) {
      await this.#processAlert(alert, summary);
    }
    return summary;
  }

  async #processAlert(
    alert: ClaimedStorageCleanupAlert,
    summary: StorageCleanupAlertBatchSummary,
  ) {
    let deliveryError: unknown;
    try {
      await this.#delivery.deliver(alert);
    } catch (error) {
      deliveryError = error;
    }

    const completion = deliveryError === undefined
      ? {
        alertId: alert.alertId,
        claimToken: alert.claimToken,
        delivered: true,
        retryable: false,
        retryDelaySeconds: 0,
      }
      : {
        alertId: alert.alertId,
        claimToken: alert.claimToken,
        delivered: false,
        retryable: isRetryable(deliveryError),
        errorCode: safeDeliveryErrorCode(deliveryError),
        retryDelaySeconds: retryDelaySeconds(
          alert.attemptCount,
          deliveryError,
        ),
      };

    try {
      applyCompletionStatus(
        summary,
        await this.#repository.complete(completion),
      );
    } catch (error) {
      summary.failed += 1;
      this.#onError(error);
    }
  }
}

function applyCompletionStatus(
  summary: StorageCleanupAlertBatchSummary,
  status: StorageCleanupAlertCompletionStatus,
) {
  switch (status) {
    case 'delivered':
      summary.delivered += 1;
      break;
    case 'pending':
      summary.retried += 1;
      break;
    case 'failed':
      summary.failed += 1;
      break;
    case 'stale':
      summary.stale += 1;
      break;
  }
}

function isRetryable(error: unknown) {
  return error instanceof StorageCleanupAlertDeliveryError
    ? error.retryable
    : true;
}

function safeDeliveryErrorCode(error: unknown) {
  if (error instanceof StorageCleanupAlertDeliveryError) {
    return error.code;
  }
  return 'storage_cleanup_alert_delivery_failed';
}

function retryDelaySeconds(
  attemptCount: number,
  error: unknown,
) {
  if (
    error instanceof StorageCleanupAlertDeliveryError &&
    error.retryAfterSeconds !== undefined
  ) {
    return Math.min(Math.max(error.retryAfterSeconds, 1), 3600);
  }
  return Math.min(60 * 2 ** Math.max(attemptCount - 1, 0), 3600);
}

function logSafeError(error: unknown) {
  const errorType = error instanceof Error ? error.name : 'UnknownError';
  console.error('storage_cleanup_alert_processing_failed', errorType);
}
