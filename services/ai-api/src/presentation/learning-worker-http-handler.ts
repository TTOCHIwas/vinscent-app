import type {
  LearningJobBatchSummary,
} from '../application/process-learning-jobs.ts';

interface LearningJobBatchProcessor {
  processBatch(limit: number): Promise<LearningJobBatchSummary>;
}

interface LearningWorkerHttpHandlerOptions {
  serviceRoleKey: string;
  processor: LearningJobBatchProcessor;
  onError?: (error: unknown) => void;
}

export function createLearningWorkerHttpHandler(
  options: LearningWorkerHttpHandlerOptions,
): (request: Request) => Promise<Response> {
  const serviceRoleKey = requireSecret(options.serviceRoleKey);
  const onError = options.onError ?? logSafeError;

  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'method_not_allowed' }, 405);
    }

    const authorization = request.headers.get('authorization');
    const providedKey = authorization?.startsWith('Bearer ')
      ? authorization.slice('Bearer '.length)
      : '';
    if (!constantTimeEquals(providedKey, serviceRoleKey)) {
      return jsonResponse({ error: 'unauthorized' }, 401);
    }

    let limit: number;
    try {
      limit = await readLimit(request);
    } catch (_) {
      return jsonResponse({ error: 'invalid_payload' }, 400);
    }

    try {
      const summary = await options.processor.processBatch(limit);
      return jsonResponse(summary);
    } catch (error) {
      onError(error);
      return jsonResponse({ error: 'ai_worker_failed' }, 500);
    }
  };
}

async function readLimit(request: Request): Promise<number> {
  const bodyText = await request.text();
  if (bodyText.trim().length === 0) {
    return 3;
  }

  const body = JSON.parse(bodyText);
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw new TypeError('request body must be an object');
  }

  const limit = Reflect.get(body, 'limit') ?? 3;
  if (!Number.isInteger(limit) || limit < 1 || limit > 5) {
    throw new RangeError('batch limit must be between 1 and 5');
  }
  return limit;
}

function requireSecret(value: string): string {
  if (value.length === 0) {
    throw new TypeError('service role key is required');
  }
  return value;
}

function constantTimeEquals(left: string, right: string): boolean {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  const maximumLength = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;

  for (let index = 0; index < maximumLength; index += 1) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return difference === 0;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function logSafeError(error: unknown): void {
  const errorType = error instanceof Error ? error.name : 'UnknownError';
  console.error('ai_learning_worker_failed', errorType);
}
