import {
  createServiceRoleClient,
  sendPushNotification,
} from '../_shared/push.ts';
import {
  extractWebhookRecordId,
  isRecord,
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';

type AnswerNotificationContext = {
  answer_id: string;
  daily_question_id: string;
  couple_id: string;
  sender_user_id: string;
  receiver_user_id: string;
  assigned_date: string;
  answered_at: string;
  question_status: string;
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'ANSWER_WEBHOOK_SECRET',
      headerName: 'x-answer-webhook-secret',
    })
  ) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  let answerId: string;
  try {
    answerId = extractWebhookRecordId(await request.json());
  } catch (error) {
    return jsonResponse(
      { error: 'invalid_payload', detail: String(error) },
      400,
    );
  }

  try {
    const supabase = createServiceRoleClient();
    const context = await loadNotificationContext(supabase, answerId);
    if (!context) {
      return jsonResponse({ status: 'skipped', error: 'answer_context_missing' });
    }

    const result = await sendPushNotification({
      supabase,
      notificationType: 'partner_answer_completed',
      sourceId: context.answer_id,
      receiverUserId: context.receiver_user_id,
      title: 'Vinscent',
      body: '상대방이 오늘 질문에 답변을 남겼어요.',
      preferenceColumn: 'partner_answer_enabled',
      data: {
        answer_id: context.answer_id,
        daily_question_id: context.daily_question_id,
        couple_id: context.couple_id,
        assigned_date: context.assigned_date,
        answered_at: context.answered_at,
      },
    });

    return jsonResponse(result);
  } catch (error) {
    return jsonResponse(
      { error: 'answer_notification_failed', detail: String(error) },
      500,
    );
  }
});

async function loadNotificationContext(
  supabase: ReturnType<typeof createServiceRoleClient>,
  answerId: string,
): Promise<AnswerNotificationContext | null> {
  const { data, error } = await supabase
    .rpc('get_daily_question_answer_notification_context', {
      requested_answer_id: answerId,
    })
    .maybeSingle();

  if (error) {
    throw new Error(`answer_context_query_failed:${error.message}`);
  }

  if (!isRecord(data)) {
    return null;
  }

  return data as AnswerNotificationContext;
}
