import type {
  ClaimedStorageCleanupAlert,
  CompleteStorageCleanupAlertRequest,
  StorageCleanupAlertCompletionStatus,
  StorageCleanupAlertKind,
  StorageCleanupAlertRepository,
  StorageCleanupCronStatus,
  StorageCleanupHealthEvaluation,
  StorageCleanupHealthStatus,
  StorageCleanupIssueCode,
} from './storage_cleanup_alert_contract.ts';

type RpcError = {
  message: string;
};

type RpcResult = {
  data: unknown;
  error: RpcError | null;
};

export interface StorageCleanupAlertRpcClient {
  rpc(
    functionName: string,
    params?: Record<string, unknown>,
  ): PromiseLike<RpcResult>;
}

const issueCodes = new Set<StorageCleanupIssueCode>([
  'failed_requests',
  'stale_processing',
  'overdue_pending',
  'cleanup_cron_missing',
  'cleanup_cron_duplicate',
  'cleanup_cron_inactive',
  'cleanup_cron_schedule_mismatch',
  'cleanup_cron_never_succeeded',
  'cleanup_cron_stale',
]);

const cronStatuses = new Set<StorageCleanupCronStatus>([
  'healthy',
  'missing',
  'duplicate',
  'inactive',
  'schedule_mismatch',
  'never_succeeded',
  'stale',
]);

export class SupabaseStorageCleanupAlertRepository
  implements StorageCleanupAlertRepository {
  readonly #client: StorageCleanupAlertRpcClient;

  constructor(client: StorageCleanupAlertRpcClient) {
    this.#client = client;
  }

  async evaluate(): Promise<StorageCleanupHealthEvaluation> {
    const { data, error } = await this.#client.rpc(
      'evaluate_storage_cleanup_health',
    );
    if (error !== null) {
      throw new Error(
        `storage_cleanup_health_evaluation_failed:${error.message}`,
      );
    }
    if (!Array.isArray(data) || data.length !== 1) {
      throw new TypeError(
        'storage_cleanup_health_evaluation_invalid_response',
      );
    }
    return parseHealthEvaluation(data[0]);
  }

  async claim(
    workerId: string,
    limit: number,
  ): Promise<ClaimedStorageCleanupAlert[]> {
    const { data, error } = await this.#client.rpc(
      'claim_storage_cleanup_operational_alerts',
      {
        requested_worker_id: workerId,
        requested_limit: limit,
      },
    );
    if (error !== null) {
      throw new Error(`storage_cleanup_alert_claim_failed:${error.message}`);
    }
    if (data === null) {
      return [];
    }
    if (!Array.isArray(data)) {
      throw new TypeError('storage_cleanup_alert_claim_invalid_response');
    }
    return data.map(parseClaimedAlert);
  }

  async complete(
    request: CompleteStorageCleanupAlertRequest,
  ): Promise<StorageCleanupAlertCompletionStatus> {
    const { data, error } = await this.#client.rpc(
      'complete_storage_cleanup_operational_alert',
      {
        requested_alert_id: request.alertId,
        requested_claim_token: request.claimToken,
        requested_delivered: request.delivered,
        requested_retryable: request.retryable,
        requested_error: request.errorCode ?? null,
        requested_retry_delay_seconds: request.retryDelaySeconds,
      },
    );
    if (error !== null) {
      throw new Error(
        `storage_cleanup_alert_complete_failed:${error.message}`,
      );
    }
    if (!isCompletionStatus(data)) {
      throw new TypeError(
        'storage_cleanup_alert_complete_invalid_response',
      );
    }
    return data;
  }
}

function parseHealthEvaluation(
  value: unknown,
): StorageCleanupHealthEvaluation {
  if (!isRecord(value)) {
    throw new TypeError(
      'storage_cleanup_health_evaluation_invalid_row',
    );
  }
  return {
    healthStatus: requiredHealthStatus(value.health_status),
    issueCodes: requiredIssueCodes(value.issue_codes, true),
    failedRequestCount: requiredNonNegativeInteger(
      value.failed_request_count,
    ),
    staleProcessingCount: requiredNonNegativeInteger(
      value.stale_processing_count,
    ),
    overduePendingCount: requiredNonNegativeInteger(
      value.overdue_pending_count,
    ),
    cleanupCronStatus: requiredCronStatus(value.cleanup_cron_status),
    cleanupCronLastSucceededAt: optionalTimestamp(
      value.cleanup_cron_last_succeeded_at,
    ),
    evaluatedAt: requiredTimestamp(value.evaluated_at),
    queuedAlertCount: requiredNonNegativeInteger(value.queued_alert_count),
  };
}

function parseClaimedAlert(value: unknown): ClaimedStorageCleanupAlert {
  if (!isRecord(value)) {
    throw new TypeError('storage_cleanup_alert_claim_invalid_row');
  }
  return {
    alertId: requiredString(value.alert_id),
    incidentId: requiredString(value.incident_id),
    claimToken: requiredString(value.claim_token),
    attemptCount: requiredPositiveInteger(value.attempt_count),
    maxAttempts: requiredPositiveInteger(value.max_attempts),
    alertKind: requiredAlertKind(value.alert_kind),
    issueCodes: requiredIssueCodes(value.issue_codes, false),
    failedRequestCount: requiredNonNegativeInteger(
      value.failed_request_count,
    ),
    staleProcessingCount: requiredNonNegativeInteger(
      value.stale_processing_count,
    ),
    overduePendingCount: requiredNonNegativeInteger(
      value.overdue_pending_count,
    ),
    cleanupCronStatus: requiredCronStatus(value.cleanup_cron_status),
    cleanupCronLastSucceededAt: optionalTimestamp(
      value.cleanup_cron_last_succeeded_at,
    ),
    detectedAt: requiredTimestamp(value.detected_at),
    incidentStartedAt: requiredTimestamp(value.incident_started_at),
  };
}

function requiredIssueCodes(
  value: unknown,
  allowEmpty: boolean,
): StorageCleanupIssueCode[] {
  if (
    !Array.isArray(value) ||
    (!allowEmpty && value.length === 0) ||
    value.some((item) => !issueCodes.has(item as StorageCleanupIssueCode))
  ) {
    throw new TypeError('storage_cleanup_alert_invalid_issue_codes');
  }
  return value as StorageCleanupIssueCode[];
}

function requiredHealthStatus(value: unknown): StorageCleanupHealthStatus {
  if (value !== 'healthy' && value !== 'degraded') {
    throw new TypeError('storage_cleanup_health_invalid_status');
  }
  return value;
}

function requiredCronStatus(value: unknown): StorageCleanupCronStatus {
  if (!cronStatuses.has(value as StorageCleanupCronStatus)) {
    throw new TypeError('storage_cleanup_alert_invalid_cron_status');
  }
  return value as StorageCleanupCronStatus;
}

function requiredAlertKind(value: unknown): StorageCleanupAlertKind {
  if (value !== 'degraded' && value !== 'recovered') {
    throw new TypeError('storage_cleanup_alert_invalid_kind');
  }
  return value;
}

function requiredTimestamp(value: unknown): string {
  if (
    typeof value !== 'string' ||
    value.length === 0 ||
    !Number.isFinite(Date.parse(value))
  ) {
    throw new TypeError('storage_cleanup_alert_invalid_timestamp');
  }
  return value;
}

function optionalTimestamp(value: unknown): string | undefined {
  if (value === null || value === undefined) {
    return undefined;
  }
  return requiredTimestamp(value);
}

function requiredString(value: unknown): string {
  if (typeof value !== 'string' || value.length === 0) {
    throw new TypeError('storage_cleanup_alert_invalid_field');
  }
  return value;
}

function requiredPositiveInteger(value: unknown): number {
  if (!Number.isInteger(value) || (value as number) < 1) {
    throw new TypeError('storage_cleanup_alert_invalid_field');
  }
  return value as number;
}

function requiredNonNegativeInteger(value: unknown): number {
  if (!Number.isInteger(value) || (value as number) < 0) {
    throw new TypeError('storage_cleanup_alert_invalid_field');
  }
  return value as number;
}

function isCompletionStatus(
  value: unknown,
): value is StorageCleanupAlertCompletionStatus {
  return value === 'delivered' ||
    value === 'pending' ||
    value === 'failed' ||
    value === 'stale';
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value);
}
