import { createFcmAccessToken, sendFcmMessage } from './fcm.ts';
import {
  claimPushNotificationDispatch,
  completePushNotificationDelivery,
  type PushDeliveryStatus,
} from './push_dispatch_repository.ts';
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

export type DeliveryStatus = PushDeliveryStatus;

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
  const dispatchClaim = await claimPushNotificationDispatch(params.supabase, {
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
      await completePushNotificationDelivery(params.supabase, {
        notificationType: params.notificationType,
        sourceId: params.sourceId,
        receiverUserId: params.receiverUserId,
        claimToken: dispatchClaim.claim_token,
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
    await completePushNotificationDelivery(params.supabase, {
      notificationType: params.notificationType,
      sourceId: params.sourceId,
      receiverUserId: params.receiverUserId,
      claimToken: dispatchClaim.claim_token,
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
    await completePushNotificationDelivery(params.supabase, {
      notificationType: params.notificationType,
      sourceId: params.sourceId,
      receiverUserId: params.receiverUserId,
      claimToken: dispatchClaim.claim_token,
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
    pushTokens.map(async (pushToken) => {
      try {
        return await sendFcmMessage(accessToken, pushToken.token, {
          title: params.title,
          body: params.body,
          type: params.notificationType,
          data: params.data,
        });
      } catch (error) {
        return {
          ok: false,
          invalidToken: false,
          errorMessage: `fcm_send_failed:${formatError(error)}`,
        };
      }
    }),
  );

  const successCount = results.filter((result) => result.ok).length;
  const failureCount = results.length - successCount;
  const invalidTokenIds = pushTokens
    .filter((_, index) => results[index].invalidToken)
    .map((pushToken) => pushToken.id);

  if (invalidTokenIds.length > 0) {
    const { error } = await params.supabase
      .from('user_push_tokens')
      .update({
        is_active: false,
        last_seen_at: new Date().toISOString(),
      })
      .in('id', invalidTokenIds);

    if (error) {
      console.error('push_token_deactivation_failed', error.message);
    }
  }

  const status = resolveDeliveryStatus(successCount, failureCount);
  await completePushNotificationDelivery(params.supabase, {
    notificationType: params.notificationType,
    sourceId: params.sourceId,
    receiverUserId: params.receiverUserId,
    claimToken: dispatchClaim.claim_token,
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

function formatError(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
