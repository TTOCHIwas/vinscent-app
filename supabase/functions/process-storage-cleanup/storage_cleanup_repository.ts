import type {
  ClaimedStorageCleanupRequest,
  CompleteStorageCleanupRequest,
  StorageCleanupCompletionStatus,
  StorageCleanupRepository,
} from './storage_cleanup_contract.ts';

type RpcError = {
  message: string;
};

type RpcResult = {
  data: unknown;
  error: RpcError | null;
};

export interface StorageCleanupRpcClient {
  rpc(
    functionName: string,
    params?: Record<string, unknown>,
  ): PromiseLike<RpcResult>;
}

export class SupabaseStorageCleanupRepository
  implements StorageCleanupRepository {
  readonly #client: StorageCleanupRpcClient;

  constructor(client: StorageCleanupRpcClient) {
    this.#client = client;
  }

  async reconcile(
    limit: number,
    minimumAgeMinutes: number,
  ): Promise<number> {
    const { data, error } = await this.#client.rpc(
      'reconcile_storage_cleanup_requests',
      {
        requested_limit: limit,
        requested_minimum_age_minutes: minimumAgeMinutes,
      },
    );
    if (error !== null) {
      throw new Error(`storage_cleanup_reconcile_failed:${error.message}`);
    }
    if (!Number.isInteger(data) || (data as number) < 0) {
      throw new TypeError('storage_cleanup_reconcile_invalid_response');
    }
    return data as number;
  }

  async claim(
    workerId: string,
    limit: number,
    requestId?: string,
  ): Promise<ClaimedStorageCleanupRequest[]> {
    const { data, error } = await this.#client.rpc(
      'claim_storage_cleanup_requests',
      {
        requested_worker_id: workerId,
        requested_limit: limit,
        requested_request_id: requestId ?? null,
      },
    );
    if (error !== null) {
      throw new Error(`storage_cleanup_claim_failed:${error.message}`);
    }
    if (data === null) {
      return [];
    }
    if (!Array.isArray(data)) {
      throw new TypeError('storage_cleanup_claim_invalid_response');
    }
    return data.map(parseClaimedRequest);
  }

  async isReferenced(
    bucketId: string,
    objectPath: string,
  ): Promise<boolean> {
    const { data, error } = await this.#client.rpc(
      'is_storage_cleanup_object_referenced',
      {
        requested_bucket_id: bucketId,
        requested_object_path: objectPath,
      },
    );
    if (error !== null) {
      throw new Error(
        `storage_cleanup_reference_check_failed:${error.message}`,
      );
    }
    if (typeof data !== 'boolean') {
      throw new TypeError(
        'storage_cleanup_reference_check_invalid_response',
      );
    }
    return data;
  }

  async complete(
    request: CompleteStorageCleanupRequest,
  ): Promise<StorageCleanupCompletionStatus> {
    const { data, error } = await this.#client.rpc(
      'complete_storage_cleanup_request',
      {
        requested_request_id: request.requestId,
        requested_claim_token: request.claimToken,
        requested_succeeded: request.succeeded,
        requested_outcome: request.outcome ?? null,
        requested_error: request.errorCode ?? null,
        requested_retry_delay_seconds: request.retryDelaySeconds,
      },
    );
    if (error !== null) {
      throw new Error(`storage_cleanup_complete_failed:${error.message}`);
    }
    if (!isCompletionStatus(data)) {
      throw new TypeError('storage_cleanup_complete_invalid_response');
    }
    return data;
  }
}

function parseClaimedRequest(value: unknown): ClaimedStorageCleanupRequest {
  if (!isRecord(value)) {
    throw new TypeError('storage_cleanup_claim_invalid_row');
  }
  return {
    requestId: requiredString(value.request_id),
    claimToken: requiredString(value.claim_token),
    attemptCount: requiredInteger(value.attempt_count),
    maxAttempts: requiredInteger(value.max_attempts),
    bucketId: requiredString(value.bucket_id),
    objectPath: requiredString(value.object_path),
    cleanupReason: requiredString(value.cleanup_reason),
  };
}

function isCompletionStatus(
  value: unknown,
): value is StorageCleanupCompletionStatus {
  return value === 'completed' ||
    value === 'pending' ||
    value === 'failed' ||
    value === 'stale';
}

function requiredString(value: unknown) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new TypeError('storage_cleanup_claim_invalid_field');
  }
  return value;
}

function requiredInteger(value: unknown) {
  if (!Number.isInteger(value) || (value as number) < 1) {
    throw new TypeError('storage_cleanup_claim_invalid_field');
  }
  return value as number;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value);
}
