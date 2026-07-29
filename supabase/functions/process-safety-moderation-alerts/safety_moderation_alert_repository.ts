import type {
  ClaimedSafetyModerationAlert,
  CompleteSafetyModerationAlertRequest,
  SafetyModerationAlertCompletionStatus,
  SafetyModerationAlertRepository,
} from './safety_moderation_alert_contract.ts';

type RpcError = {
  message: string;
};

type RpcResult = {
  data: unknown;
  error: RpcError | null;
};

export interface SafetyModerationRpcClient {
  rpc(
    functionName: string,
    params?: Record<string, unknown>,
  ): PromiseLike<RpcResult>;
}

export class SupabaseSafetyModerationAlertRepository
  implements SafetyModerationAlertRepository {
  readonly #client: SafetyModerationRpcClient;

  constructor(client: SafetyModerationRpcClient) {
    this.#client = client;
  }

  async claim(
    workerId: string,
    limit: number,
  ): Promise<ClaimedSafetyModerationAlert[]> {
    const { data, error } = await this.#client.rpc(
      'claim_safety_moderation_alerts',
      {
        requested_worker_id: workerId,
        requested_limit: limit,
      },
    );
    if (error !== null) {
      throw new Error(
        `moderation_alert_claim_failed:${error.message}`,
      );
    }

    if (data === null) {
      return [];
    }
    if (!Array.isArray(data)) {
      throw new TypeError('moderation_alert_claim_invalid_response');
    }
    return data.map(parseClaimedAlert);
  }

  async complete(
    request: CompleteSafetyModerationAlertRequest,
  ): Promise<SafetyModerationAlertCompletionStatus> {
    const { data, error } = await this.#client.rpc(
      'complete_safety_moderation_alert',
      {
        requested_report_id: request.reportId,
        requested_claim_token: request.claimToken,
        requested_delivered: request.delivered,
        requested_error: request.errorCode ?? null,
        requested_retry_delay_seconds: request.retryDelaySeconds,
      },
    );
    if (error !== null) {
      throw new Error(
        `moderation_alert_complete_failed:${error.message}`,
      );
    }
    if (!isCompletionStatus(data)) {
      throw new TypeError('moderation_alert_complete_invalid_response');
    }
    return data;
  }
}

function parseClaimedAlert(value: unknown): ClaimedSafetyModerationAlert {
  if (!isRecord(value)) {
    throw new TypeError('moderation_alert_claim_invalid_row');
  }

  return {
    reportId: requiredString(value.report_id),
    claimToken: requiredString(value.claim_token),
    attemptCount: requiredInteger(value.attempt_count),
    maxAttempts: requiredInteger(value.max_attempts),
    targetType: requiredString(value.target_type),
    reason: requiredString(value.reason),
    hasDetails: hasNonEmptyString(value.details),
    hasContentSnapshot: hasNonEmptyString(value.content_snapshot),
    reportCreatedAt: requiredString(value.report_created_at),
  };
}

function isCompletionStatus(
  value: unknown,
): value is SafetyModerationAlertCompletionStatus {
  return value === 'delivered' ||
    value === 'pending' ||
    value === 'failed' ||
    value === 'stale';
}

function requiredString(value: unknown): string {
  if (typeof value !== 'string' || value.length === 0) {
    throw new TypeError('moderation_alert_claim_invalid_field');
  }
  return value;
}

function requiredInteger(value: unknown): number {
  if (!Number.isInteger(value) || (value as number) < 1) {
    throw new TypeError('moderation_alert_claim_invalid_field');
  }
  return value as number;
}

function hasNonEmptyString(value: unknown): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value);
}
