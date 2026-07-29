export type SafetyModerationAlertCompletionStatus =
  | 'delivered'
  | 'pending'
  | 'failed'
  | 'stale';

export type ClaimedSafetyModerationAlert = {
  reportId: string;
  claimToken: string;
  attemptCount: number;
  maxAttempts: number;
  targetType: string;
  reason: string;
  hasDetails: boolean;
  hasContentSnapshot: boolean;
  reportCreatedAt: string;
};

export type CompleteSafetyModerationAlertRequest = {
  reportId: string;
  claimToken: string;
  delivered: boolean;
  errorCode?: string;
  retryDelaySeconds: number;
};

export interface SafetyModerationAlertRepository {
  claim(
    workerId: string,
    limit: number,
  ): Promise<ClaimedSafetyModerationAlert[]>;

  complete(
    request: CompleteSafetyModerationAlertRequest,
  ): Promise<SafetyModerationAlertCompletionStatus>;
}

export interface SafetyModerationAlertDelivery {
  deliver(alert: ClaimedSafetyModerationAlert): Promise<void>;
}

export type SafetyModerationAlertBatchSummary = {
  claimed: number;
  delivered: number;
  retried: number;
  failed: number;
  stale: number;
};

export class SafetyModerationDeliveryError extends Error {
  readonly code: string;

  constructor(code: string) {
    super(code);
    this.name = 'SafetyModerationDeliveryError';
    this.code = code;
  }
}
