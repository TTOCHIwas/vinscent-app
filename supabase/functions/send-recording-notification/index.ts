import {
  createServiceRoleClient,
  isRecord,
  jsonResponse,
  sendPushNotification,
  verifyWebhookSecret,
} from '../_shared/push.ts';

type RecordingEventRecord = {
  id: string;
};

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
      fallbackEnvName: 'EXPRESSION_WEBHOOK_SECRET',
      fallbackHeaderName: 'x-expression-webhook-secret',
    })
  ) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  let eventRecord: RecordingEventRecord;
  try {
    const payload = await request.json();
    eventRecord = extractRecordingEventRecord(payload);
  } catch (error) {
    return jsonResponse(
      { error: 'invalid_payload', detail: String(error) },
      400,
    );
  }

  try {
    const supabase = createServiceRoleClient();
    const event = await loadNotificationEvent(supabase, eventRecord.id);
    if (!event) {
      return jsonResponse({ status: 'skipped', error: 'recording_event_missing' });
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

function extractRecordingEventRecord(payload: unknown): RecordingEventRecord {
  if (!isRecord(payload)) {
    throw new Error('payload must be an object');
  }

  const candidate = isRecord(payload.record) ? payload.record : payload;
  if (typeof candidate.id !== 'string' || candidate.id === '') {
    throw new Error('missing id');
  }

  return { id: candidate.id as string };
}

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
  return switch (event.event_type) {
    'current_recording_updated' => '새 녹음을 남겼어요.',
    'slot_saved' => '녹음을 보관함에 저장했어요.',
    'slot_replaced' => '보관함 녹음을 새로 바꿨어요.',
    'slot_deleted' => '보관함 녹음을 삭제했어요.',
    _ => '녹음 보관함이 업데이트됐어요.',
  };
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
