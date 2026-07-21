import { sendPushNotification } from '../_shared/push.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';
import {
  extractWebhookRecordId,
  isRecord,
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';

type RecordingNotificationEvent = {
  id: string;
  couple_id: string;
  sender_user_id: string;
  receiver_user_id: string;
  event_type: string;
  recording_id: string | null;
  slot_index: number | null;
  slot_title: string | null;
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'RECORDING_WEBHOOK_SECRET',
      headerName: 'x-recording-webhook-secret',
    })
  ) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  let eventId: string;
  try {
    eventId = extractWebhookRecordId(await request.json());
  } catch (error) {
    return jsonResponse(
      { error: 'invalid_payload', detail: String(error) },
      400,
    );
  }

  try {
    const supabase = createServiceRoleClient();
    const event = await loadNotificationEvent(supabase, eventId);
    if (!event) {
      return jsonResponse({
        status: 'skipped',
        error: 'recording_event_missing',
      });
    }

    const result = await sendPushNotification({
      supabase,
      notificationType: 'recording_activity',
      sourceId: event.id,
      receiverUserId: event.receiver_user_id,
      title: 'Vinscent',
      body: notificationBodyFor(event),
      preferenceColumn: 'recording_enabled',
      data: notificationDataFor(event),
    });

    return jsonResponse(result);
  } catch (error) {
    return jsonResponse(
      { error: 'recording_notification_failed', detail: String(error) },
      500,
    );
  }
});

async function loadNotificationEvent(
  supabase: ReturnType<typeof createServiceRoleClient>,
  eventId: string,
): Promise<RecordingNotificationEvent | null> {
  const { data, error } = await supabase
    .from('recording_notification_events')
    .select(
      'id, couple_id, sender_user_id, receiver_user_id, event_type, recording_id, slot_index, slot_title',
    )
    .eq('id', eventId)
    .maybeSingle();

  if (error) {
    throw new Error(`recording_event_query_failed:${error.message}`);
  }

  if (!isRecord(data)) {
    return null;
  }

  return data as RecordingNotificationEvent;
}

function notificationBodyFor(event: RecordingNotificationEvent) {
  switch (event.event_type) {
    case 'current_recording_updated':
      return '새 녹음을 남겼어요.';
    case 'slot_saved':
      return '녹음을 보관함에 저장했어요.';
    case 'slot_replaced':
      return '보관함의 녹음을 새로 바꿨어요.';
    case 'slot_deleted':
      return '보관함의 녹음을 삭제했어요.';
    default:
      return '녹음 보관함이 업데이트됐어요.';
  }
}

function notificationDataFor(event: RecordingNotificationEvent) {
  return {
    event_id: event.id,
    couple_id: event.couple_id,
    event_type: event.event_type,
    ...(event.recording_id ? { recording_id: event.recording_id } : {}),
    ...(event.slot_index !== null
      ? { slot_index: String(event.slot_index) }
      : {}),
    ...(event.slot_title ? { slot_title: event.slot_title } : {}),
  };
}
