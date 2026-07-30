import type {
  ClaimedStorageCleanupRequest,
  CompleteStorageCleanupRequest,
  StorageCleanupBatchOptions,
  StorageCleanupBatchSummary,
  StorageCleanupCompletionStatus,
  StorageCleanupOutcome,
  StorageCleanupRepository,
  StorageCleanupSingleResult,
  StorageObjectStore,
} from './storage_cleanup_contract.ts';

type StorageCleanupProcessorOptions = {
  repository: StorageCleanupRepository;
  objectStore: StorageObjectStore;
  workerId: string;
  onError?: (error: unknown) => void;
};

export class StorageCleanupProcessor {
  readonly #repository: StorageCleanupRepository;
  readonly #objectStore: StorageObjectStore;
  readonly #workerId: string;
  readonly #onError: (error: unknown) => void;

  constructor(options: StorageCleanupProcessorOptions) {
    this.#repository = options.repository;
    this.#objectStore = options.objectStore;
    this.#workerId = options.workerId.trim();
    if (this.#workerId.length === 0 || this.#workerId.length > 120) {
      throw new TypeError('storage cleanup worker id is invalid');
    }
    this.#onError = options.onError ?? logSafeError;
  }

  async processBatch(
    options: StorageCleanupBatchOptions,
  ): Promise<StorageCleanupBatchSummary> {
    const reconciled = options.reconcileLimit === 0
      ? 0
      : await this.#repository.reconcile(
        options.reconcileLimit,
        options.minimumAgeMinutes,
      );
    const requests = await this.#repository.claim(
      this.#workerId,
      options.limit,
    );
    const summary: StorageCleanupBatchSummary = {
      reconciled,
      claimed: requests.length,
      deleted: 0,
      preserved: 0,
      retried: 0,
      failed: 0,
      stale: 0,
    };

    for (const request of requests) {
      const result = await this.#processClaimedRequest(request);
      applyResult(summary, result);
    }
    return summary;
  }

  async processRequest(requestId: string): Promise<StorageCleanupSingleResult> {
    const requests = await this.#repository.claim(
      this.#workerId,
      1,
      requestId,
    );
    const request = requests[0];
    if (!request) {
      return {
        status: 'skipped',
        error: 'storage_cleanup_request_unavailable',
      };
    }
    return this.#processClaimedRequest(request);
  }

  async #processClaimedRequest(
    request: ClaimedStorageCleanupRequest,
  ): Promise<StorageCleanupSingleResult> {
    let referenced: boolean;
    try {
      referenced = await this.#repository.isReferenced(
        request.bucketId,
        request.objectPath,
      );
    } catch (error) {
      this.#onError(error);
      return this.#completeFailure(
        request,
        'storage_reference_check_failed',
      );
    }

    if (referenced) {
      return this.#completeSuccess(request, 'still_referenced');
    }

    try {
      await this.#objectStore.remove(request.bucketId, request.objectPath);
    } catch (error) {
      this.#onError(error);
      return this.#completeFailure(
        request,
        'storage_object_delete_failed',
      );
    }
    return this.#completeSuccess(request, 'deleted');
  }

  async #completeSuccess(
    request: ClaimedStorageCleanupRequest,
    outcome: StorageCleanupOutcome,
  ): Promise<StorageCleanupSingleResult> {
    const status = await this.#complete({
      requestId: request.requestId,
      claimToken: request.claimToken,
      succeeded: true,
      outcome,
      retryDelaySeconds: 0,
    });
    return {
      status,
      outcome,
      bucketId: request.bucketId,
      objectPath: request.objectPath,
      cleanupReason: request.cleanupReason,
    };
  }

  async #completeFailure(
    request: ClaimedStorageCleanupRequest,
    errorCode: string,
  ): Promise<StorageCleanupSingleResult> {
    const status = await this.#complete({
      requestId: request.requestId,
      claimToken: request.claimToken,
      succeeded: false,
      errorCode,
      retryDelaySeconds: retryDelaySeconds(request.attemptCount),
    });
    return {
      status,
      bucketId: request.bucketId,
      objectPath: request.objectPath,
      cleanupReason: request.cleanupReason,
      error: errorCode,
    };
  }

  async #complete(
    request: CompleteStorageCleanupRequest,
  ): Promise<StorageCleanupCompletionStatus> {
    try {
      return await this.#repository.complete(request);
    } catch (error) {
      this.#onError(error);
      return 'failed';
    }
  }
}

function applyResult(
  summary: StorageCleanupBatchSummary,
  result: StorageCleanupSingleResult,
) {
  if (result.status === 'completed') {
    if (result.outcome === 'deleted') {
      summary.deleted += 1;
    } else if (result.outcome === 'still_referenced') {
      summary.preserved += 1;
    }
    return;
  }

  switch (result.status) {
    case 'pending':
      summary.retried += 1;
      break;
    case 'failed':
      summary.failed += 1;
      break;
    case 'stale':
    case 'skipped':
      summary.stale += 1;
      break;
  }
}

function retryDelaySeconds(attemptCount: number) {
  return Math.min(60 * 2 ** Math.max(attemptCount - 1, 0), 3600);
}

function logSafeError(error: unknown) {
  const errorType = error instanceof Error ? error.name : 'UnknownError';
  console.error('storage_cleanup_processing_failed', errorType);
}
