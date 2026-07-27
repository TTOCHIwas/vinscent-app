import {
  finalizeExhaustedPushNotificationDispatches,
  isPushNotificationRetryEligible,
  loadRetryablePushNotificationDispatches,
  type RetryablePushNotificationDispatch,
} from '../_shared/push_dispatch_repository.ts';
import {
  isNotificationType,
  isPreferenceColumn,
  sendPushNotification,
} from '../_shared/push.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';
import { dispatchInBatches } from './dispatch_in_batches.ts';

type PushRetryHandlerParams = {
  supabase: ReturnType<typeof createServiceRoleClient>;
  accessToken: string;
};

const retryBatchSize = 100;
const dispatchConcurrency = 4;

export function loadRetryablePushNotificationJobs(
  supabase: ReturnType<typeof createServiceRoleClient>,
) {
  return prepareRetryablePushNotificationJobs(supabase);
}

async function prepareRetryablePushNotificationJobs(
  supabase: ReturnType<typeof createServiceRoleClient>,
) {
  await finalizeExhaustedPushNotificationDispatches(
    supabase,
    retryBatchSize,
  );
  return loadRetryablePushNotificationDispatches(supabase, retryBatchSize);
}

export function dispatchRetryablePushNotificationJobs(
  jobs: RetryablePushNotificationDispatch[],
  params: PushRetryHandlerParams,
) {
  return dispatchInBatches(jobs, dispatchConcurrency, async (job) => {
    if (!isNotificationType(job.notification_type)) {
      throw new Error('retryable_push_notification_type_invalid');
    }

    if (
      job.preference_column !== null &&
      !isPreferenceColumn(job.preference_column)
    ) {
      throw new Error('retryable_push_preference_column_invalid');
    }

    const result = await sendPushNotification({
      supabase: params.supabase,
      notificationType: job.notification_type,
      sourceId: job.source_id,
      receiverUserId: job.receiver_user_id,
      title: job.title,
      body: job.body,
      data: job.data,
      preferenceColumn: job.preference_column ?? undefined,
      accessToken: params.accessToken,
      maxAttempts: job.max_attempts,
      eligibilityCheck: () =>
        isPushNotificationRetryEligible(params.supabase, {
          notificationType: job.notification_type,
          sourceId: job.source_id,
          receiverUserId: job.receiver_user_id,
          data: job.data,
        }),
    });

    return { notificationType: job.notification_type, ...result };
  });
}
