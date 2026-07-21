import { requiredEnv } from './environment.ts';
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

type FcmSendResult = {
  ok: boolean;
  invalidToken: boolean;
  errorMessage: string | null;
};

type FcmErrorSummary = {
  status: string | null;
  errorCode: string | null;
  message: string | null;
  raw: string;
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

const defaultAndroidChannelId = 'vinscent_notifications';

export async function createFcmAccessToken() {
  const clientEmail = requiredEnv('FCM_CLIENT_EMAIL');
  const privateKey = requiredEnv('FCM_PRIVATE_KEY').replace(/\\n/g, '\n');
  const issuedAt = Math.floor(Date.now() / 1000);
  const expiresAt = issuedAt + 3600;
  const header = { alg: 'RS256', typ: 'JWT' };
  const claimSet = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: issuedAt,
    exp: expiresAt,
  };

  const unsignedToken = [
    base64UrlEncode(JSON.stringify(header)),
    base64UrlEncode(JSON.stringify(claimSet)),
  ].join('.');
  const cryptoKey = await importPrivateKey(privateKey);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsignedToken),
  );
  const jwt = `${unsignedToken}.${base64UrlEncode(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    throw new Error(`fcm_access_token_failed: ${await response.text()}`);
  }

  const data = await response.json();
  if (!isRecord(data) || typeof data.access_token !== 'string') {
    throw new Error('fcm_access_token_missing');
  }

  return data.access_token;
}

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

async function sendFcmMessage(
  accessToken: string,
  token: string,
  params: {
    title: string;
    body: string;
    type: NotificationType;
    data: Record<string, string>;
  },
): Promise<FcmSendResult> {
  const projectId = requiredEnv('FCM_PROJECT_ID');
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: params.title,
            body: params.body,
          },
          data: {
            type: params.type,
            ...params.data,
          },
          android: {
            priority: 'HIGH',
            notification: {
              channel_id: defaultAndroidChannelId,
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
              },
            },
          },
        },
      }),
    },
  );

  if (response.ok) {
    return { ok: true, invalidToken: false, errorMessage: null };
  }

  const errorBody = await response.text();
  const errorSummary = parseFcmErrorSummary(errorBody);
  return {
    ok: false,
    invalidToken: isInvalidFcmTokenError(errorSummary),
    errorMessage: formatFcmErrorSummary(errorSummary),
  };
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

function parseFcmErrorSummary(errorBody: string): FcmErrorSummary {
  try {
    const payload = JSON.parse(errorBody);
    const error = isRecord(payload) && isRecord(payload.error)
      ? payload.error
      : null;
    const details = error && Array.isArray(error.details) ? error.details : [];
    const fcmDetail = details.find(
      (detail) => isRecord(detail) && typeof detail.errorCode === 'string',
    );
    const errorCode =
      isRecord(fcmDetail) && typeof fcmDetail.errorCode === 'string'
        ? fcmDetail.errorCode
        : null;

    return {
      status: typeof error?.status === 'string' ? error.status : null,
      errorCode,
      message: typeof error?.message === 'string' ? error.message : null,
      raw: errorBody,
    };
  } catch (_) {
    return {
      status: null,
      errorCode: null,
      message: null,
      raw: errorBody,
    };
  }
}

function formatFcmErrorSummary(summary: FcmErrorSummary) {
  const parts = [
    summary.status ? `status=${summary.status}` : null,
    summary.errorCode ? `errorCode=${summary.errorCode}` : null,
    summary.message ? `message=${summary.message}` : null,
  ].filter((part): part is string => Boolean(part));

  if (parts.length > 0) {
    return parts.join('; ');
  }

  return summary.raw.slice(0, 1000);
}

function isInvalidFcmTokenError(summary: FcmErrorSummary) {
  return summary.errorCode === 'UNREGISTERED';
}

async function importPrivateKey(privateKey: string) {
  const keyData = privateKey
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binaryKey = Uint8Array.from(atob(keyData), (char) =>
    char.charCodeAt(0),
  );

  return crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign'],
  );
}

function base64UrlEncode(value: string | ArrayBuffer) {
  const bytes =
    typeof value === 'string'
      ? new TextEncoder().encode(value)
      : new Uint8Array(value);
  let binary = '';

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}
