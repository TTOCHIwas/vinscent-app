import { requiredEnv } from './environment.ts';
import { isRecord } from './webhook.ts';

export type FcmSendResult = {
  ok: boolean;
  invalidToken: boolean;
  errorMessage: string | null;
};

export type FcmErrorSummary = {
  status: string | null;
  errorCode: string | null;
  message: string | null;
  raw: string;
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

export async function sendFcmMessage(
  accessToken: string,
  token: string,
  params: {
    title: string;
    body: string;
    type: string;
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

  const errorSummary = parseFcmErrorSummary(await response.text());
  return {
    ok: false,
    invalidToken: isInvalidFcmTokenError(errorSummary),
    errorMessage: formatFcmErrorSummary(errorSummary),
  };
}

export function parseFcmErrorSummary(errorBody: string): FcmErrorSummary {
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

export function formatFcmErrorSummary(summary: FcmErrorSummary) {
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

export function isInvalidFcmTokenError(summary: FcmErrorSummary) {
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
