import {
  extractWebhookRecordId,
  internalErrorResponse,
  invalidPayloadResponse,
  isRecord,
  jsonResponse,
} from '../_shared/webhook.ts';
import type {
  StorageCleanupBatchOptions,
  StorageCleanupBatchSummary,
  StorageCleanupSingleResult,
} from './storage_cleanup_contract.ts';

interface StorageCleanupRequestProcessor {
  processRequest(requestId: string): Promise<StorageCleanupSingleResult>;
  processBatch(
    options: StorageCleanupBatchOptions,
  ): Promise<StorageCleanupBatchSummary>;
}

type StorageCleanupHttpHandlerOptions = {
  processor: StorageCleanupRequestProcessor;
  maximumBatchSize?: number;
  maximumReconcileBatchSize?: number;
  minimumReconcileAgeMinutes?: number;
  onError?: (code: string, errorType: string) => void;
};

export function createStorageCleanupHttpHandler(
  options: StorageCleanupHttpHandlerOptions,
) {
  const maximumBatchSize = options.maximumBatchSize ?? 20;
  const maximumReconcileBatchSize =
    options.maximumReconcileBatchSize ?? 100;
  const minimumReconcileAgeMinutes =
    options.minimumReconcileAgeMinutes ?? 60;

  validateConfiguration(
    maximumBatchSize,
    maximumReconcileBatchSize,
    minimumReconcileAgeMinutes,
  );

  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'method_not_allowed' }, 405);
    }

    let payload: Record<string, unknown>;
    try {
      payload = await readPayload(request);
    } catch {
      return invalidPayloadResponse();
    }

    try {
      if ('record' in payload || 'id' in payload) {
        return jsonResponse(
          await options.processor.processRequest(
            readWebhookRecordId(payload),
          ),
        );
      }

      return jsonResponse(await options.processor.processBatch({
        limit: readPositiveInteger(
          payload.limit,
          maximumBatchSize,
          maximumBatchSize,
        ),
        reconcileLimit: readNonNegativeInteger(
          payload.reconcileLimit,
          maximumReconcileBatchSize,
          maximumReconcileBatchSize,
        ),
        minimumAgeMinutes: minimumReconcileAgeMinutes,
      }));
    } catch (error) {
      if (error instanceof PayloadError) {
        return invalidPayloadResponse();
      }
      return internalErrorResponse(
        'storage_cleanup_failed',
        error,
        options.onError,
      );
    }
  };
}

function readWebhookRecordId(payload: Record<string, unknown>) {
  try {
    return extractWebhookRecordId(payload);
  } catch {
    throw new PayloadError();
  }
}

async function readPayload(request: Request) {
  const text = await request.text();
  if (text.trim().length === 0) {
    return {};
  }
  const payload = JSON.parse(text);
  if (!isRecord(payload)) {
    throw new PayloadError();
  }
  return payload;
}

function readPositiveInteger(
  value: unknown,
  fallback: number,
  maximum: number,
) {
  if (value === undefined) {
    return fallback;
  }
  if (!Number.isInteger(value) || (value as number) < 1) {
    throw new PayloadError();
  }
  return Math.min(value as number, maximum);
}

function readNonNegativeInteger(
  value: unknown,
  fallback: number,
  maximum: number,
) {
  if (value === undefined) {
    return fallback;
  }
  if (!Number.isInteger(value) || (value as number) < 0) {
    throw new PayloadError();
  }
  return Math.min(value as number, maximum);
}

function validateConfiguration(
  maximumBatchSize: number,
  maximumReconcileBatchSize: number,
  minimumReconcileAgeMinutes: number,
) {
  if (
    !Number.isInteger(maximumBatchSize) ||
    maximumBatchSize < 1 ||
    maximumBatchSize > 100
  ) {
    throw new RangeError('storage cleanup batch size is invalid');
  }
  if (
    !Number.isInteger(maximumReconcileBatchSize) ||
    maximumReconcileBatchSize < 1 ||
    maximumReconcileBatchSize > 500
  ) {
    throw new RangeError('storage reconciliation batch size is invalid');
  }
  if (
    !Number.isInteger(minimumReconcileAgeMinutes) ||
    minimumReconcileAgeMinutes < 15 ||
    minimumReconcileAgeMinutes > 1440
  ) {
    throw new RangeError('storage reconciliation age is invalid');
  }
}

class PayloadError extends Error {}
