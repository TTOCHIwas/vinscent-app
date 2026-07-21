import { createFcmAccessToken, sendFcmMessage } from './fcm.ts';
import { createServiceRoleClient } from './supabase.ts';
import { isRecord } from './webhook.ts';

export type NotificationType =
  | 'partner_answer_completed'
  | 'daily_question_delivery'
  | 'unanswered_reminder'
  | 'couple_disconnect'
  | 'recording_activity'
  | 'partner_story_card_uploaded'
  | 'question_generated'
  | 'couple_activity'
  | 'ai_update';

export type DeliveryStatus =
  | 'sent'
  | 'partial_failure'
  | 'failed'
  | 'skipped';

export type PreferenceColumn =
  | 'partner_answer_enabled'
  | 'daily_question_enabled'
  | 'reminder_enabled'
  | 'couple_disconnect_enabled'
  | 'recording_enabled'
  | 'partner_story_card_enabled'
  | 'couple_activity_enabled'
  | 'ai_updates_enabled';

type PushTokenRow = {
  id: string;
  token: string;
};

type DispatchClaimRow = {
  claim_result: 'claimed' | 'duplicate';
  notification_type: string;
  source_id: string;
  receiver_user_id: string;
  dispatch_status: string;
  claimed_at: string;
};

export type NotificationDispatchResult = {
  status: DeliveryStatus | 'duplicate';
  targetTokenCount: number;
  successCount: number;
  failureCount: number;
  dispatchStatus?: string;
};

type SendPushNotificationParams = {
  supabase: ReturnType<typeof createServiceRoleClient>;
  notificationType: NotificationType;
  sourceId: string;
  receiverUserId: string;
  title: string;
  body: string;
  data: Record<string, string>;
  preferenceColumn?: PreferenceColumn;
  accessToken?: string;
};

export async function sendPushNotification(
  params: SendPushNotificationParams,
): Promise<NotificationDispatchResult> {
  const dispatchClaim = await claimNotificationDispatch(params.supabase, {
    notificationType: params.notificationType,
    sourceId: params.sourceId,
    receiverUserId: params.receiverUserId,
  });

  if (dispatchClaim.claim_result !== 'claimed') {
    return {
      status: 'duplicate',
      targetTokenCount: 0,
      successCount: 0,
      failureCount: 0,
      dispatchStatus: dispatchClaim.dispatch_status,
    };
  }

  if (params.preferenceColumn) {
    const isEnabled = await isNotificationEnabled(
      params.supabase,
      params.receiverUserId,
      params.preferenceColumn,
    );

    if (!isEnabled) {
      await recordDeliveryAndCompleteDispatch(params.supabase, {
        notificationType: params.notificationType,
        sourceId: params.sourceId,
        receiverUserId: params.receiverUserId,
        targetTokenCount: 0,
        successCount: 0,
        failureCount: 0,
        status: 'skipped',
        errorMessage: 'notification_disabled',
      });

      return {
        status: 'skipped',
        targetTokenCount: 0,
        successCount: 0,
        failureCount: 0,
      };
    }
  }

  const { data: pushTokenRows, error: tokenError } = await params.supabase
    .from('user_push_tokens')
    .select('id, token')
    .eq('user_id', params.receiverUserId)
    .eq('is_active', true);

  if (tokenError) {
    await recordDeliveryAndCompleteDispatch(params.supabase, {
      notificationType: params.notificationType,
      sourceId: params.sourceId,
      receiverUserId: params.receiverUserId,
      targetTokenCount: 0,
      successCount: 0,
      failureCount: 0,
      status: 'failed',
      errorMessage: tokenError.message,
    });

    throw new Error(`push_token_query_failed:${tokenError.message}`);
  }

  const pushTokens = (pushTokenRows ?? []) as PushTokenRow[];
  if (pushTokens.length === 0) {
    await recordDeliveryAndCompleteDispatch(params.supabase, {
      notificationType: params.notificationType,
      sourceId: params.sourceId,
      receiverUserId: params.receiverUserId,
      targetTokenCount: 0,
      successCount: 0,
      failureCount: 0,
      status: 'skipped',
      errorMessage: 'no_active_push_tokens',
    });

    return {
      status: 'skipped',
      targetTokenCount: 0,
      successCount: 0,
      failureCount: 0,
    };
  }

  const accessToken = params.accessToken ?? (await createFcmAccessToken());
  const results = await Promise.all(
    pushTokens.map((pushToken) =>
      sendFcmMessage(accessToken, pushToken.token, {
        title: params.title,
        body: params.body,
        type: params.notificationType,
        data: params.data,
      }),
    ),
  );

  const successCount = results.filter((result) => result.ok).length;
  const failureCount = results.length - successCount;
  const invalidTokenIds = pushTokens
    .filter((_, index) => results[index].invalidToken)
    .map((pushToken) => pushToken.id);

  if (invalidTokenIds.length > 0) {
    await params.supabase
      .from('user_push_tokens')
      .update({
        is_active: false,
        last_seen_at: new Date().toISOString(),
      })
      .in('id', invalidTokenIds);
  }

  const status = resolveDeliveryStatus(successCount, failureCount);
  await recordDeliveryAndCompleteDispatch(params.supabase, {
    notificationType: params.notificationType,
    sourceId: params.sourceId,
    receiverUserId: params.receiverUserId,
    targetTokenCount: pushTokens.length,
    successCount,
    failureCount,
    status,
    errorMessage: summarizeErrors(results),
  });

  return {
    status,
    targetTokenCount: pushTokens.length,
    successCount,
    failureCount,
  };
}

async function isNotificationEnabled(
  supabase: ReturnType<typeof createServiceRoleClient>,
  receiverUserId: string,
  preferenceColumn: PreferenceColumn,
) {
  const { data, error } = await supabase
    .from('user_notification_preferences')
    .select(preferenceColumn)
    .eq('user_id', receiverUserId)
    .maybeSingle();

  if (error) {
    throw new Error(`notification_preference_query_failed:${error.message}`);
  }

  if (!isRecord(data)) {
    return true;
  }

  return Reflect.get(data, preferenceColumn) !== false;
}

async function claimNotificationDispatch(
  supabase: ReturnType<typeof createServiceRoleClient>,
  params: {
    notificationType: NotificationType;
    sourceId: string;
    receiverUserId: string;
  },
): Promise<DispatchClaimRow> {
  const { data, error } = await supabase
    .rpc('claim_push_notification_dispatch', {
      requested_notification_type: params.notificationType,
      requested_source_id: params.sourceId,
      requested_receiver_user_id: params.receiverUserId,
    })
    .single();

  if (error) {
    throw new Error(`dispatch_claim_failed:${error.message}`);
  }

  if (!isRecord(data) || typeof data.claim_result !== 'string') {
    throw new Error('dispatch_claim_missing');
  }

  return data as DispatchClaimRow;
}

async function recordDeliveryAndCompleteDispatch(
  supabase: ReturnType<typeof createServiceRoleClient>,
  params: {
    notificationType: NotificationType;
    sourceId: string;
    receiverUserId: string;
    targetTokenCount: number;
    successCount: number;
    failureCount: number;
    status: DeliveryStatus;
    errorMessage: string | null;
  },
) {
  await logDelivery(supabase, params);
  await completeNotificationDispatch(supabase, {
    notificationType: params.notificationType,
    sourceId: params.sourceId,
    receiverUserId: params.receiverUserId,
    status: params.status,
    errorMessage: params.errorMessage,
  });
}

async function logDelivery(
  supabase: ReturnType<typeof createServiceRoleClient>,
  params: {
    notificationType: NotificationType;
    sourceId: string;
    receiverUserId: string;
    targetTokenCount: number;
    successCount: number;
    failureCount: number;
    status: DeliveryStatus;
    errorMessage: string | null;
  },
) {
  await supabase.from('push_notification_deliveries').insert({
    notification_type: params.notificationType,
    source_id: params.sourceId,
    receiver_user_id: params.receiverUserId,
    target_token_count: params.targetTokenCount,
    success_count: params.successCount,
    failure_count: params.failureCount,
    status: params.status,
    error_message: params.errorMessage,
  });
}

async function completeNotificationDispatch(
  supabase: ReturnType<typeof createServiceRoleClient>,
  params: {
    notificationType: NotificationType;
    sourceId: string;
    receiverUserId: string;
    status: DeliveryStatus;
    errorMessage: string | null;
  },
) {
  const { error } = await supabase.rpc('complete_push_notification_dispatch', {
    requested_notification_type: params.notificationType,
    requested_source_id: params.sourceId,
    requested_receiver_user_id: params.receiverUserId,
    requested_status: params.status,
    requested_error_message: params.errorMessage,
  });

  if (error) {
    console.error('complete_push_notification_dispatch_failed', error.message);
  }
}

function resolveDeliveryStatus(
  successCount: number,
  failureCount: number,
): DeliveryStatus {
  if (successCount > 0 && failureCount === 0) {
    return 'sent';
  }

  if (successCount > 0 && failureCount > 0) {
    return 'partial_failure';
  }

  return 'failed';
}

function summarizeErrors(
  results: Array<{ errorMessage: string | null }>,
): string | null {
  const messages = results
    .map((result) => result.errorMessage)
    .filter((message): message is string => Boolean(message));

  if (messages.length === 0) {
    return null;
  }

  return messages.slice(0, 3).join('\n');
}
