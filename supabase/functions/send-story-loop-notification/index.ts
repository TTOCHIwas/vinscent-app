import { sendPushNotification } from '../_shared/push.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';
import {
  extractWebhookRecordId,
  isRecord,
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';

type StoryLoopEventRecord = {
  id: string;
  couple_id: string;
  story_loop_id: string;
  card_id: string | null;
  receiver_user_id: string;
  event_type: 'partner_story_card_uploaded' | 'question_generated';
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'STORY_LOOP_WEBHOOK_SECRET',
      headerName: 'x-story-loop-webhook-secret',
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
      return jsonResponse({ status: 'skipped', error: 'story_loop_event_missing' });
    }

    const result = await sendPushNotification({
      supabase,
      notificationType: event.event_type,
      sourceId: event.id,
      receiverUserId: event.receiver_user_id,
      title: 'Vinscent',
      body: notificationBodyFor(event.event_type),
      preferenceColumn: preferenceColumnFor(event.event_type),
      data: {
        event_id: event.id,
        couple_id: event.couple_id,
        story_loop_id: event.story_loop_id,
        event_type: event.event_type,
        ...(event.card_id ? { card_id: event.card_id } : {}),
      },
    });

    return jsonResponse(result);
  } catch (error) {
    return jsonResponse(
      { error: 'story_loop_notification_failed', detail: String(error) },
      500,
    );
  }
});

async function loadEvent(
  supabase: ReturnType<typeof createServiceRoleClient>,
  eventId: string,
): Promise<StoryLoopEventRecord | null> {
  const { data, error } = await supabase
    .from('story_loop_notification_events')
    .select('id, couple_id, story_loop_id, card_id, receiver_user_id, event_type')
    .eq('id', eventId)
    .maybeSingle();

  if (error) {
    throw new Error(`story_loop_event_query_failed:${error.message}`);
  }

  if (!isRecord(data)) {
    return null;
  }

  if (
    data.event_type !== 'partner_story_card_uploaded' &&
    data.event_type !== 'question_generated'
  ) {
    throw new Error('invalid_story_loop_event_type');
  }

  return data as StoryLoopEventRecord;
}

function notificationBodyFor(eventType: StoryLoopEventRecord['event_type']) {
  return eventType === 'partner_story_card_uploaded'
    ? '상대방이 오늘의 스토리 카드를 올렸어요.'
    : '두 사람의 오늘 질문이 생성됐어요.';
}

function preferenceColumnFor(eventType: StoryLoopEventRecord['event_type']) {
  return eventType === 'partner_story_card_uploaded'
    ? 'partner_story_card_enabled' as const
    : 'daily_question_enabled' as const;
}
