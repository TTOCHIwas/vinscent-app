import {
  createServiceRoleClient,
  isRecord,
  jsonResponse,
  sendPushNotification,
  verifyWebhookSecret,
} from '../_shared/push.ts';

type CoupleRecord = {
  id: string;
  user_a_id: string;
  user_b_id: string;
  status: string;
  disconnected_at?: string;
  disconnected_by_user_id?: string;
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'COUPLE_WEBHOOK_SECRET',
      headerName: 'x-couple-webhook-secret',
      fallbackEnvName: 'EXPRESSION_WEBHOOK_SECRET',
      fallbackHeaderName: 'x-expression-webhook-secret',
    })
  ) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  let couple: CoupleRecord;
  try {
    const payload = await request.json();
    couple = extractCoupleRecord(payload);
  } catch (error) {
    return jsonResponse(
      { error: 'invalid_payload', detail: String(error) },
      400,
    );
  }

  if (
    couple.status !== 'disconnected' ||
    !couple.disconnected_at ||
    !couple.disconnected_by_user_id
  ) {
    return jsonResponse({ status: 'skipped', error: 'not_disconnected' });
  }

  const receiverUserId = resolveReceiverUserId(couple);
  if (!receiverUserId) {
    return jsonResponse({ status: 'skipped', error: 'receiver_not_found' });
  }

  try {
    const supabase = createServiceRoleClient();
    const result = await sendPushNotification({
      supabase,
      notificationType: 'couple_disconnect',
      sourceId: couple.id,
      receiverUserId,
      title: 'Vinscent',
      body: '상대방이 커플 연결을 해제했어요.',
      preferenceColumn: 'couple_disconnect_enabled',
      data: {
        couple_id: couple.id,
        disconnected_at: couple.disconnected_at,
        disconnected_by_user_id: couple.disconnected_by_user_id,
      },
    });

    return jsonResponse(result);
  } catch (error) {
    return jsonResponse(
      { error: 'couple_disconnect_notification_failed', detail: String(error) },
      500,
    );
  }
});

function extractCoupleRecord(payload: unknown): CoupleRecord {
  if (!isRecord(payload)) {
    throw new Error('payload must be an object');
  }

  const candidate = isRecord(payload.record) ? payload.record : payload;
  const requiredFields = ['id', 'user_a_id', 'user_b_id', 'status'];

  for (const field of requiredFields) {
    if (typeof candidate[field] !== 'string' || candidate[field] === '') {
      throw new Error(`missing ${field}`);
    }
  }

  return {
    id: candidate.id as string,
    user_a_id: candidate.user_a_id as string,
    user_b_id: candidate.user_b_id as string,
    status: candidate.status as string,
    disconnected_at:
      typeof candidate.disconnected_at === 'string'
        ? candidate.disconnected_at
        : undefined,
    disconnected_by_user_id:
      typeof candidate.disconnected_by_user_id === 'string'
        ? candidate.disconnected_by_user_id
        : undefined,
  };
}

function resolveReceiverUserId(couple: CoupleRecord) {
  if (couple.disconnected_by_user_id === couple.user_a_id) {
    return couple.user_b_id;
  }

  if (couple.disconnected_by_user_id === couple.user_b_id) {
    return couple.user_a_id;
  }

  return null;
}
