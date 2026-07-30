export type StorageCleanupOutcome = 'deleted' | 'still_referenced';

export type StorageCleanupCompletionStatus =
  | 'completed'
  | 'pending'
  | 'failed'
  | 'stale';

export type ClaimedStorageCleanupRequest = {
  requestId: string;
  claimToken: string;
  attemptCount: number;
  maxAttempts: number;
  bucketId: string;
  objectPath: string;
  cleanupReason: string;
};

export type CompleteStorageCleanupRequest = {
  requestId: string;
  claimToken: string;
  succeeded: boolean;
  outcome?: StorageCleanupOutcome;
  errorCode?: string;
  retryDelaySeconds: number;
};

export type StorageCleanupBatchOptions = {
  limit: number;
  reconcileLimit: number;
  minimumAgeMinutes: number;
};

export type StorageCleanupBatchSummary = {
  reconciled: number;
  claimed: number;
  deleted: number;
  preserved: number;
  retried: number;
  failed: number;
  stale: number;
};

export type StorageCleanupSingleResult = {
  status: StorageCleanupCompletionStatus | 'skipped';
  outcome?: StorageCleanupOutcome;
  bucketId?: string;
  objectPath?: string;
  cleanupReason?: string;
  error?: string;
};

export interface StorageCleanupRepository {
  reconcile(limit: number, minimumAgeMinutes: number): Promise<number>;
  claim(
    workerId: string,
    limit: number,
    requestId?: string,
  ): Promise<ClaimedStorageCleanupRequest[]>;
  isReferenced(bucketId: string, objectPath: string): Promise<boolean>;
  complete(
    request: CompleteStorageCleanupRequest,
  ): Promise<StorageCleanupCompletionStatus>;
}

export interface StorageObjectStore {
  remove(bucketId: string, objectPath: string): Promise<void>;
}
