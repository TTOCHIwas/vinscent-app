import {
  createServiceRoleClient,
  isRecord,
  jsonResponse,
  sendPushNotification,
  verifyWebhookSecret,
} from '../_shared/push.ts';

type CoupleExpressionRecord = {
  id: string;
  couple_id: string;
  sender_user_id: string;
  receiver_user_id: string;
  expression_type: string;
  sent_at?: string;
};

const expressionMessages: Record<string, string> = {
  miss_you: '상대방이 보고 싶다는 마음을 보냈어요.',
  thanks: '상대방이 고마운 마음을 전했어요.',
  feeling_down: '상대방이 조금 지친 마음을 표현했어요.',
  cheer_up: '상대방이 응원의 마음을 보냈어요.',
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'EXPRESSION_WEBHOOK_SECRET',
      headerName: 'x-expression-webhook-secret',
    })
  ) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

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
    return jsonResponse({ status: 'skipped', error: 'invalid_expression_type' });
  }

  try {
    const supabase = createServiceRoleClient();
    const result = await sendPushNotification({
      supabase,
      notificationType: 'couple_expression',
      sourceId: expression.id,
      receiverUserId: expression.receiver_user_id,
      title: 'Vinscent',
      body: notificationBody,
      preferenceColumn: 'expression_enabled',
      data: {
        expression_id: expression.id,
        expression_type: expression.expression_type,
        couple_id: expression.couple_id,
        sent_at: expression.sent_at ?? '',
      },
    });

    return jsonResponse(result);
  } catch (error) {
    return jsonResponse(
      { error: 'expression_notification_failed', detail: String(error) },
      500,
    );
  }
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
