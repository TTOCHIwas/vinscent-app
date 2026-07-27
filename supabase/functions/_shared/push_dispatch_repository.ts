import type { createServiceRoleClient } from './supabase.ts';
import { isRecord } from './webhook.ts';

type PushPersistenceError = {
  message: string;
};

type PushPersistenceResult<T> = {
  data: T | null;
  error: PushPersistenceError | null;
};

type PushPersistenceOptions = {
  maxAttempts?: number;
  delay?: (milliseconds: number) => Promise<void>;
};

export type PushDispatchClaim = {
  claim_result: 'claimed' | 'duplicate';
  notification_type: string;
  source_id: string;
  receiver_user_id: string;
  claim_token: string;
  dispatch_status: string;
  claimed_at: string;
  attempt_count: number;
  max_attempts: number;
  available_at: string;
};

export type PushDeliveryStatus =
  | 'sent'
  | 'partial_failure'
  | 'failed'
  | 'skipped';

type PushDispatchKey = {
  notificationType: string;
  sourceId: string;
  receiverUserId: string;
};

type PushDispatchRequest = PushDispatchKey & {
  title: string;
  body: string;
  data: Record<string, string>;
  preferenceColumn: string | null;
  maxAttempts: number;
};

export type RetryablePushNotificationDispatch = {
  notification_type: string;
  source_id: string;
  receiver_user_id: string;
  title: string;
  body: string;
  data: Record<string, string>;
  preference_column: string | null;
  attempt_count: number;
  max_attempts: number;
  available_at: string;
};

export type PushDeliveryCompletion = PushDispatchKey & {
  claimToken: string;
  targetTokenCount: number;
  successCount: number;
  failureCount: number;
  status: PushDeliveryStatus;
  errorMessage: string | null;
};

export async function claimPushNotificationDispatch(
  supabase: ReturnType<typeof createServiceRoleClient>,
  params: PushDispatchRequest,
): Promise<PushDispatchClaim> {
  const { data, error } = await supabase
    .rpc('claim_push_notification_dispatch', {
      requested_notification_type: params.notificationType,
      requested_source_id: params.sourceId,
      requested_receiver_user_id: params.receiverUserId,
      requested_title: params.title,
      requested_body: params.body,
      requested_data: params.data,
      requested_preference_column: params.preferenceColumn,
      requested_max_attempts: params.maxAttempts,
    })
    .single();

  if (error) {
    throw new Error(`dispatch_claim_failed:${error.message}`);
  }

  return parsePushDispatchClaim(data);
}

export async function loadRetryablePushNotificationDispatches(
  supabase: ReturnType<typeof createServiceRoleClient>,
  limit: number,
): Promise<RetryablePushNotificationDispatch[]> {
  const { data, error } = await supabase.rpc(
    'get_retryable_push_notification_dispatches',
    { requested_limit: limit },
  );

  if (error) {
    throw new Error(`retryable_push_dispatch_query_failed:${error.message}`);
  }

  if (!Array.isArray(data)) {
    throw new Error('retryable_push_dispatches_missing');
  }

  return data.map(parseRetryablePushNotificationDispatch);
}

export async function finalizeExhaustedPushNotificationDispatches(
  supabase: ReturnType<typeof createServiceRoleClient>,
  limit: number,
) {
  const { data, error } = await supabase.rpc(
    'finalize_exhausted_push_notification_dispatches',
    { requested_limit: limit },
  );

  if (error) {
    throw new Error(`exhausted_push_dispatch_finalize_failed:${error.message}`);
  }

  if (!Number.isInteger(data) || data < 0) {
    throw new Error('exhausted_push_dispatch_finalize_result_invalid');
  }

  return data;
}

export async function completePushNotificationDelivery(
  supabase: ReturnType<typeof createServiceRoleClient>,
  params: PushDeliveryCompletion,
) {
  const result = await runPushPersistenceOperation(
    'complete_push_notification_delivery',
    () =>
      supabase.rpc('complete_push_notification_delivery', {
        requested_notification_type: params.notificationType,
        requested_source_id: params.sourceId,
        requested_receiver_user_id: params.receiverUserId,
        requested_claim_token: params.claimToken,
        requested_target_token_count: params.targetTokenCount,
        requested_success_count: params.successCount,
        requested_failure_count: params.failureCount,
        requested_status: params.status,
        requested_error_message: params.errorMessage,
      }),
  );

  if (result !== 'completed' && result !== 'duplicate') {
    throw new Error('complete_push_notification_delivery_missing');
  }
}

export function parsePushDispatchClaim(value: unknown): PushDispatchClaim {
  if (!isRecord(value) || typeof value.claim_result !== 'string') {
    throw new Error('dispatch_claim_missing');
  }

  if (value.claim_result !== 'claimed' && value.claim_result !== 'duplicate') {
    throw new Error('dispatch_claim_invalid');
  }

  if (typeof value.claim_token !== 'string' || value.claim_token === '') {
    throw new Error('dispatch_claim_token_missing');
  }

  if (
    !Number.isInteger(value.attempt_count) ||
    !Number.isInteger(value.max_attempts) ||
    typeof value.available_at !== 'string'
  ) {
    throw new Error('dispatch_claim_retry_metadata_missing');
  }

  return value as PushDispatchClaim;
}

export function parseRetryablePushNotificationDispatch(
  value: unknown,
): RetryablePushNotificationDispatch {
  if (
    !isRecord(value) ||
    typeof value.notification_type !== 'string' ||
    typeof value.source_id !== 'string' ||
    typeof value.receiver_user_id !== 'string' ||
    typeof value.title !== 'string' ||
    typeof value.body !== 'string' ||
    !isStringRecord(value.data) ||
    (
      value.preference_column !== null &&
      typeof value.preference_column !== 'string'
    ) ||
    !Number.isInteger(value.attempt_count) ||
    !Number.isInteger(value.max_attempts) ||
    typeof value.available_at !== 'string'
  ) {
    throw new Error('retryable_push_dispatch_invalid');
  }

  return value as RetryablePushNotificationDispatch;
}

export async function runPushPersistenceOperation<T>(
  operationName: string,
  operation: () => PromiseLike<PushPersistenceResult<T>>,
  options: PushPersistenceOptions = {},
): Promise<T | null> {
  const maxAttempts = Math.max(1, options.maxAttempts ?? 3);
  const delay = options.delay ?? wait;
  let lastError = 'unknown';

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const { data, error } = await operation();
      if (!error) {
        return data;
      }
      lastError = error.message;
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
    }

    if (attempt < maxAttempts) {
      await delay(100 * 2 ** (attempt - 1));
    }
  }

  throw new Error(`${operationName}_failed:${lastError}`);
}

function wait(milliseconds: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
}

function isStringRecord(value: unknown): value is Record<string, string> {
  return isRecord(value) &&
    Object.values(value).every((item) => typeof item === 'string');
}
