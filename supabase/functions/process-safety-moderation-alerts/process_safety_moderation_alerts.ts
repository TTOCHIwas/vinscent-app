import {
  type ClaimedSafetyModerationAlert,
  type SafetyModerationAlertBatchSummary,
  type SafetyModerationAlertCompletionStatus,
  SafetyModerationDeliveryError,
  type SafetyModerationAlertDelivery,
  type SafetyModerationAlertRepository,
} from './safety_moderation_alert_contract.ts';

type ProcessSafetyModerationAlertsOptions = {
  repository: SafetyModerationAlertRepository;
  delivery: SafetyModerationAlertDelivery;
  workerId: string;
  onError?: (error: unknown) => void;
};

export class SafetyModerationAlertProcessor {
  readonly #repository: SafetyModerationAlertRepository;
  readonly #delivery: SafetyModerationAlertDelivery;
  readonly #workerId: string;
  readonly #onError: (error: unknown) => void;

  constructor(options: ProcessSafetyModerationAlertsOptions) {
    this.#repository = options.repository;
    this.#delivery = options.delivery;
    this.#workerId = options.workerId.trim();
    if (
      this.#workerId.length === 0 ||
      this.#workerId.length > 120
    ) {
      throw new TypeError('moderation worker id is invalid');
    }
    this.#onError = options.onError ?? logSafeError;
  }

  async processBatch(
    limit: number,
  ): Promise<SafetyModerationAlertBatchSummary> {
    const alerts = await this.#repository.claim(this.#workerId, limit);
    const summary: SafetyModerationAlertBatchSummary = {
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
    alert: ClaimedSafetyModerationAlert,
    summary: SafetyModerationAlertBatchSummary,
  ) {
    let deliveryError: unknown;
    try {
      await this.#delivery.deliver(alert);
    } catch (error) {
      deliveryError = error;
    }

    if (deliveryError === undefined) {
      try {
        const status = await this.#repository.complete({
          reportId: alert.reportId,
          claimToken: alert.claimToken,
          delivered: true,
          retryDelaySeconds: 0,
        });
        applyCompletionStatus(summary, status);
      } catch (error) {
        summary.failed += 1;
        this.#onError(error);
      }
      return;
    }

    try {
      const status = await this.#repository.complete({
        reportId: alert.reportId,
        claimToken: alert.claimToken,
        delivered: false,
        errorCode: safeDeliveryErrorCode(deliveryError),
        retryDelaySeconds: retryDelaySeconds(alert.attemptCount),
      });
      applyCompletionStatus(summary, status);
    } catch (error) {
      summary.failed += 1;
      this.#onError(error);
    }
  }
}

function applyCompletionStatus(
  summary: SafetyModerationAlertBatchSummary,
  status: SafetyModerationAlertCompletionStatus,
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

function safeDeliveryErrorCode(error: unknown) {
  if (error instanceof SafetyModerationDeliveryError) {
    return error.code;
  }
  return 'moderation_webhook_delivery_failed';
}

function retryDelaySeconds(attemptCount: number) {
  return Math.min(60 * 2 ** Math.max(attemptCount - 1, 0), 3600);
}

function logSafeError(error: unknown) {
  const errorType = error instanceof Error ? error.name : 'UnknownError';
  console.error('safety_moderation_alert_processing_failed', errorType);
}
