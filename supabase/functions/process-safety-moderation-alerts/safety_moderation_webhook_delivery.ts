import {
  type ClaimedSafetyModerationAlert,
  SafetyModerationDeliveryError,
  type SafetyModerationAlertDelivery,
} from './safety_moderation_alert_contract.ts';

type SafetyModerationWebhookDeliveryOptions = {
  endpoint: string;
  bearerToken?: string;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
};

export class SafetyModerationWebhookDelivery
  implements SafetyModerationAlertDelivery {
  readonly #endpoint: URL;
  readonly #bearerToken?: string;
  readonly #timeoutMs: number;
  readonly #fetch: typeof fetch;

  constructor(options: SafetyModerationWebhookDeliveryOptions) {
    this.#endpoint = parseHttpsEndpoint(options.endpoint);
    this.#bearerToken = normalizeOptionalSecret(options.bearerToken);
    this.#timeoutMs = options.timeoutMs ?? 10_000;
    if (
      !Number.isInteger(this.#timeoutMs) ||
      this.#timeoutMs < 1 ||
      this.#timeoutMs > 30_000
    ) {
      throw new RangeError(
        'moderation webhook timeout must be between 1 and 30000 milliseconds',
      );
    }
    this.#fetch = options.fetchImpl ?? fetch;
  }

  async deliver(alert: ClaimedSafetyModerationAlert): Promise<void> {
    const headers = new Headers({
      'content-type': 'application/json',
      'x-danjjan-event-id': alert.reportId,
    });
    if (this.#bearerToken !== undefined) {
      headers.set('authorization', `Bearer ${this.#bearerToken}`);
    }

    let response: Response;
    try {
      response = await this.#fetch(this.#endpoint, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          type: 'danjjan.safety_report.created',
          version: 1,
          report: {
            id: alert.reportId,
            targetType: alert.targetType,
            reason: alert.reason,
            createdAt: alert.reportCreatedAt,
            hasDetails: alert.hasDetails,
            hasContentSnapshot: alert.hasContentSnapshot,
          },
        }),
        signal: AbortSignal.timeout(this.#timeoutMs),
      });
    } catch {
      throw new SafetyModerationDeliveryError(
        'moderation_webhook_unavailable',
      );
    }

    if (response.ok) {
      return;
    }
    if (response.status === 429) {
      throw new SafetyModerationDeliveryError(
        'moderation_webhook_rate_limited',
      );
    }
    if (response.status >= 500) {
      throw new SafetyModerationDeliveryError(
        'moderation_webhook_unavailable',
      );
    }
    throw new SafetyModerationDeliveryError(
      'moderation_webhook_rejected',
    );
  }
}

function parseHttpsEndpoint(value: string): URL {
  const endpoint = new URL(value);
  if (endpoint.protocol !== 'https:') {
    throw new TypeError('moderation webhook endpoint must use HTTPS');
  }
  return endpoint;
}

function normalizeOptionalSecret(value: string | undefined) {
  const normalized = value?.trim();
  return normalized ? normalized : undefined;
}
