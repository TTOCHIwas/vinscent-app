import { sendPushNotification } from '../_shared/push.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';
import {
  extractWebhookRecordId,
  isRecord,
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';
import {
  type AppEventType,
  appEventTypeSet,
  notificationBodyFor,
  notificationTypeFor,
  preferenceColumnFor,
  routeFor,
} from './notification_contract.ts';

type AppNotificationEvent = {
  id: string;
  couple_id: string;
  receiver_user_id: string;
  event_type: AppEventType;
  daily_question_id: string | null;
  curriculum_version: number | null;
  payload: Record<string, unknown>;
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'APP_NOTIFICATION_WEBHOOK_SECRET',
      headerName: 'x-app-notification-webhook-secret',
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
    const event = await loadEvent(supabase, eventId);
    if (!event) {
      return jsonResponse({ status: 'skipped', error: 'app_event_missing' });
    }

    const result = await sendPushNotification({
      supabase,
      notificationType: notificationTypeFor(event.event_type),
      sourceId: event.id,
      receiverUserId: event.receiver_user_id,
      title: 'Vinscent',
      body: notificationBodyFor(event.event_type),
      preferenceColumn: preferenceColumnFor(event.event_type),
      data: notificationDataFor(event),
    });

    return jsonResponse(result);
  } catch (error) {
    return jsonResponse(
      { error: 'app_notification_failed', detail: String(error) },
      500,
    );
  }
});

async function loadEvent(
  supabase: ReturnType<typeof createServiceRoleClient>,
  eventId: string,
): Promise<AppNotificationEvent | null> {
  const { data, error } = await supabase
    .from('app_notification_events')
    .select(
      'id, couple_id, receiver_user_id, event_type, daily_question_id, curriculum_version, payload',
    )
    .eq('id', eventId)
    .maybeSingle();

  if (error) {
    throw new Error(`app_notification_event_query_failed:${error.message}`);
  }

  if (!isRecord(data)) {
    return null;
  }

  if (
    typeof data.event_type !== 'string' ||
    !appEventTypeSet.has(data.event_type as AppEventType)
  ) {
    throw new Error('invalid_app_notification_event_type');
  }

  return {
    id: data.id as string,
    couple_id: data.couple_id as string,
    receiver_user_id: data.receiver_user_id as string,
    event_type: data.event_type as AppEventType,
    daily_question_id:
      typeof data.daily_question_id === 'string'
        ? data.daily_question_id
        : null,
    curriculum_version:
      typeof data.curriculum_version === 'number'
        ? data.curriculum_version
        : null,
    payload: isRecord(data.payload) ? data.payload : {},
  };
}

function notificationDataFor(event: AppNotificationEvent) {
  const assignedDate = event.payload.assigned_date;
  const userQuestionId = event.payload.user_question_id;
  const route = routeFor(event.event_type, assignedDate);

  return {
    event_id: event.id,
    couple_id: event.couple_id,
    event_type: event.event_type,
    route,
    ...(event.daily_question_id
      ? { daily_question_id: event.daily_question_id }
      : {}),
    ...(event.curriculum_version !== null
      ? { curriculum_version: String(event.curriculum_version) }
      : {}),
    ...(typeof assignedDate === 'string'
      ? { assigned_date: assignedDate }
      : {}),
    ...(typeof userQuestionId === 'string'
      ? { user_question_id: userQuestionId }
      : {}),
  };
}
