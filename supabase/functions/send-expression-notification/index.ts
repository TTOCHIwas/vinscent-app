import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.86.0';

type CoupleExpressionRecord = {
  id: string;
  couple_id: string;
  sender_user_id: string;
  receiver_user_id: string;
  expression_type: string;
  sent_at?: string;
};

type PushTokenRow = {
  id: string;
  token: string;
};

type DeliveryStatus = 'sent' | 'partial_failure' | 'failed' | 'skipped';

const expressionMessages: Record<string, string> = {
  miss_you: '상대방이 보고싶다고 표현했어요',
  thanks: '상대방이 고마운 마음을 보냈어요',
  feeling_down: '상대방이 조금 우울한 마음을 표현했어요',
  cheer_up: '상대방이 응원을 보냈어요',
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  const configuredSecret = Deno.env.get('EXPRESSION_WEBHOOK_SECRET');
  const requestSecret = request.headers.get('x-expression-webhook-secret');

  if (!configuredSecret || requestSecret !== configuredSecret) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  const supabaseUrl = requiredEnv('SUPABASE_URL');
  const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  let expression: CoupleExpressionRecord;
  try {
    const payload = await request.json();
    expression = extractExpressionRecord(payload);
  } catch (error) {
    return jsonResponse(
      { error: 'invalid_payload', detail: String(error) },
      400,
    );
  }

  const notificationBody = expressionMessages[expression.expression_type];
  if (!notificationBody) {
    await logDelivery(supabase, {
      expression,
      targetTokenCount: 0,
      successCount: 0,
      failureCount: 0,
      status: 'skipped',
      errorMessage: 'invalid_expression_type',
    });

    return jsonResponse({ status: 'skipped' });
  }

  const { data: pushTokenRows, error: tokenError } = await supabase
    .from('user_push_tokens')
    .select('id, token')
    .eq('user_id', expression.receiver_user_id)
    .eq('is_active', true);

  if (tokenError) {
    await logDelivery(supabase, {
      expression,
      targetTokenCount: 0,
      successCount: 0,
      failureCount: 0,
      status: 'failed',
      errorMessage: tokenError.message,
    });

    return jsonResponse({ error: 'push_token_query_failed' }, 500);
  }

  const pushTokens = (pushTokenRows ?? []) as PushTokenRow[];

  if (pushTokens.length === 0) {
    await logDelivery(supabase, {
      expression,
      targetTokenCount: 0,
      successCount: 0,
      failureCount: 0,
      status: 'skipped',
      errorMessage: 'no_active_push_tokens',
    });

    return jsonResponse({ status: 'skipped', targetTokenCount: 0 });
  }

  let results: Array<{
    ok: boolean;
    invalidToken: boolean;
    errorMessage: string | null;
  }>;

  try {
    const accessToken = await createFcmAccessToken();
    results = await Promise.all(
      pushTokens.map((pushToken) =>
        sendFcmMessage(
          accessToken,
          pushToken.token,
          expression,
          notificationBody,
        ),
      ),
    );
  } catch (error) {
    await logDelivery(supabase, {
      expression,
      targetTokenCount: pushTokens.length,
      successCount: 0,
      failureCount: pushTokens.length,
      status: 'failed',
      errorMessage: String(error),
    });

    return jsonResponse({ error: 'fcm_send_failed' }, 500);
  }

  const successCount = results.filter((result) => result.ok).length;
  const failureCount = results.length - successCount;
  const invalidTokenIds = pushTokens
    .filter((_, index) => results[index].invalidToken)
    .map((pushToken) => pushToken.id);

  if (invalidTokenIds.length > 0) {
    await supabase
      .from('user_push_tokens')
      .update({
        is_active: false,
        last_seen_at: new Date().toISOString(),
      })
      .in('id', invalidTokenIds);
  }

  const status = resolveDeliveryStatus(successCount, failureCount);
  await logDelivery(supabase, {
    expression,
    targetTokenCount: pushTokens.length,
    successCount,
    failureCount,
    status,
    errorMessage: summarizeErrors(results),
  });

  return jsonResponse({
    status,
    targetTokenCount: pushTokens.length,
    successCount,
    failureCount,
  });
});

function extractExpressionRecord(payload: unknown): CoupleExpressionRecord {
  if (!isRecord(payload)) {
    throw new Error('payload must be an object');
  }

  const candidate = isRecord(payload.record) ? payload.record : payload;
  const requiredFields = [
    'id',
    'couple_id',
    'sender_user_id',
    'receiver_user_id',
    'expression_type',
  ];

  for (const field of requiredFields) {
    if (typeof candidate[field] !== 'string' || candidate[field] === '') {
      throw new Error(`missing ${field}`);
    }
  }

  return {
    id: candidate.id as string,
    couple_id: candidate.couple_id as string,
    sender_user_id: candidate.sender_user_id as string,
    receiver_user_id: candidate.receiver_user_id as string,
    expression_type: candidate.expression_type as string,
    sent_at:
      typeof candidate.sent_at === 'string' ? candidate.sent_at : undefined,
  };
}

async function sendFcmMessage(
  accessToken: string,
  token: string,
  expression: CoupleExpressionRecord,
  body: string,
) {
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
            title: 'Vinscent',
            body,
          },
          data: {
            type: 'couple_expression',
            expression_id: expression.id,
            expression_type: expression.expression_type,
            couple_id: expression.couple_id,
            sent_at: expression.sent_at ?? '',
          },
          android: {
            priority: 'HIGH',
            notification: {
              channel_id: 'couple_expression_notifications',
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
  return {
    ok: false,
    invalidToken: isInvalidFcmTokenError(errorBody),
    errorMessage: errorBody,
  };
}

async function createFcmAccessToken() {
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

async function logDelivery(
  supabase: ReturnType<typeof createClient>,
  params: {
    expression: CoupleExpressionRecord;
    targetTokenCount: number;
    successCount: number;
    failureCount: number;
    status: DeliveryStatus;
    errorMessage: string | null;
  },
) {
  await supabase.from('push_notification_deliveries').insert({
    notification_type: 'couple_expression',
    source_id: params.expression.id,
    receiver_user_id: params.expression.receiver_user_id,
    target_token_count: params.targetTokenCount,
    success_count: params.successCount,
    failure_count: params.failureCount,
    status: params.status,
    error_message: params.errorMessage,
  });
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

function isInvalidFcmTokenError(errorBody: string) {
  return (
    /"errorCode"\s*:\s*"UNREGISTERED"/.test(errorBody) ||
    /"errorCode"\s*:\s*"INVALID_ARGUMENT"/.test(errorBody)
  );
}

function requiredEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`missing_env:${name}`);
  }

  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
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
