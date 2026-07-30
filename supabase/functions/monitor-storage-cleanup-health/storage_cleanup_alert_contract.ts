export type StorageCleanupHealthStatus = 'healthy' | 'degraded';

export type StorageCleanupCronStatus =
  | 'healthy'
  | 'missing'
  | 'duplicate'
  | 'inactive'
  | 'schedule_mismatch'
  | 'never_succeeded'
  | 'stale';

export type StorageCleanupIssueCode =
  | 'failed_requests'
  | 'stale_processing'
  | 'overdue_pending'
  | 'cleanup_cron_missing'
  | 'cleanup_cron_duplicate'
  | 'cleanup_cron_inactive'
  | 'cleanup_cron_schedule_mismatch'
  | 'cleanup_cron_never_succeeded'
  | 'cleanup_cron_stale';

export type StorageCleanupAlertKind = 'degraded' | 'recovered';

export type StorageCleanupAlertCompletionStatus =
  | 'delivered'
  | 'pending'
  | 'failed'
  | 'stale';

export type StorageCleanupHealthEvaluation = {
  healthStatus: StorageCleanupHealthStatus;
  issueCodes: StorageCleanupIssueCode[];
  failedRequestCount: number;
  staleProcessingCount: number;
  overduePendingCount: number;
  cleanupCronStatus: StorageCleanupCronStatus;
  cleanupCronLastSucceededAt?: string;
  evaluatedAt: string;
  queuedAlertCount: number;
};

export type ClaimedStorageCleanupAlert = {
  alertId: string;
  incidentId: string;
  claimToken: string;
  attemptCount: number;
  maxAttempts: number;
  alertKind: StorageCleanupAlertKind;
  issueCodes: StorageCleanupIssueCode[];
  failedRequestCount: number;
  staleProcessingCount: number;
  overduePendingCount: number;
  cleanupCronStatus: StorageCleanupCronStatus;
  cleanupCronLastSucceededAt?: string;
  detectedAt: string;
  incidentStartedAt: string;
};

export type CompleteStorageCleanupAlertRequest = {
  alertId: string;
  claimToken: string;
  delivered: boolean;
  retryable: boolean;
  errorCode?: string;
  retryDelaySeconds: number;
};

export interface StorageCleanupAlertRepository {
  evaluate(): Promise<StorageCleanupHealthEvaluation>;

  claim(
    workerId: string,
    limit: number,
  ): Promise<ClaimedStorageCleanupAlert[]>;

  complete(
    request: CompleteStorageCleanupAlertRequest,
  ): Promise<StorageCleanupAlertCompletionStatus>;
}

export interface StorageCleanupAlertDelivery {
  deliver(alert: ClaimedStorageCleanupAlert): Promise<void>;
}

export type StorageCleanupAlertBatchSummary = {
  healthStatus: StorageCleanupHealthStatus;
  issueCodes: StorageCleanupIssueCode[];
  queued: number;
  claimed: number;
  delivered: number;
  retried: number;
  failed: number;
  stale: number;
};

type StorageCleanupAlertDeliveryErrorOptions = {
  retryable: boolean;
  retryAfterSeconds?: number;
};

export class StorageCleanupAlertDeliveryError extends Error {
  readonly code: string;
  readonly retryable: boolean;
  readonly retryAfterSeconds?: number;

  constructor(
    code: string,
    options: StorageCleanupAlertDeliveryErrorOptions,
  ) {
    super(code);
    this.name = 'StorageCleanupAlertDeliveryError';
    this.code = code;
    this.retryable = options.retryable;
    this.retryAfterSeconds = options.retryAfterSeconds;
  }
}
