import {
  internalErrorResponse,
  invalidPayloadResponse,
  isRecord,
  jsonResponse,
} from '../_shared/webhook.ts';
import type {
  SafetyModerationAlertBatchSummary,
} from './safety_moderation_alert_contract.ts';

interface SafetyModerationBatchProcessor {
  processBatch(limit: number): Promise<SafetyModerationAlertBatchSummary>;
}

type SafetyModerationWorkerHttpHandlerOptions = {
  processor: SafetyModerationBatchProcessor;
  maximumBatchSize?: number;
  onError?: (code: string, errorType: string) => void;
};

export function createSafetyModerationWorkerHttpHandler(
  options: SafetyModerationWorkerHttpHandlerOptions,
) {
  const maximumBatchSize = options.maximumBatchSize ?? 20;
  if (
    !Number.isInteger(maximumBatchSize) ||
    maximumBatchSize < 1 ||
    maximumBatchSize > 100
  ) {
    throw new RangeError(
      'moderation worker batch size must be between 1 and 100',
    );
  }

  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'method_not_allowed' }, 405);
    }

    let limit: number;
    try {
      limit = await readBatchLimit(request, maximumBatchSize);
    } catch {
      return invalidPayloadResponse();
    }

    try {
      return jsonResponse(await options.processor.processBatch(limit));
    } catch (error) {
      return internalErrorResponse(
        'safety_moderation_worker_failed',
        error,
        options.onError,
      );
    }
  };
}

async function readBatchLimit(
  request: Request,
  maximumBatchSize: number,
) {
  const text = await request.text();
  if (text.trim().length === 0) {
    return Math.min(20, maximumBatchSize);
  }

  const body = JSON.parse(text);
  if (!isRecord(body)) {
    throw new TypeError('request body must be an object');
  }

  const limit = body.limit ?? 20;
  if (!Number.isInteger(limit) || (limit as number) < 1) {
    throw new RangeError('batch limit must be a positive integer');
  }
  return Math.min(limit as number, maximumBatchSize);
}
