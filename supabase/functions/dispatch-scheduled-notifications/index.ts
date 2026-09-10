import { createFcmAccessToken } from '../_shared/fcm.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';
import {
  internalErrorResponse,
  invalidPayloadResponse,
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';
import {
  dispatchCalendarEventReminderJobs,
  loadDueCalendarEventReminderJobs,
} from './calendar_event_reminder_handler.ts';
import {
  dispatchDailyQuestionDeliveryJobs,
  loadDueDailyQuestionDeliveryJobs,
} from './daily_question_delivery_handler.ts';
import {
  dispatchUnansweredQuestionReminderJobs,
  loadDueUnansweredQuestionReminderJobs,
} from './unanswered_question_reminder_handler.ts';
import {
  dispatchRetryablePushNotificationJobs,
  loadRetryablePushNotificationJobs,
} from './push_retry_handler.ts';
import {
  finalizeExpiredStoryCardsSafely,
} from './story_card_rollover_handler.ts';

const defaultLookbackMinutes = 10;

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'SCHEDULE_WEBHOOK_SECRET',
      headerName: 'x-schedule-webhook-secret',
    })
  ) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  let requestBody: Record<string, unknown>;
  try {
    requestBody = await parseRequestBody(request);
  } catch {
    return invalidPayloadResponse();
  }
  const lookbackMinutes = normalizeLookbackMinutes(
    requestBody.lookback_minutes,
  );
  const runAt = normalizeRunAt(requestBody.run_at);

  try {
    const supabase = createServiceRoleClient();
    const [
      deliveryJobs,
      questionJobs,
      calendarJobs,
      retryJobs,
      storyCardRollover,
    ] = await Promise.all([
      loadDueDailyQuestionDeliveryJobs(supabase, runAt),
      loadDueUnansweredQuestionReminderJobs(
        supabase,
        runAt,
      ),
      loadDueCalendarEventReminderJobs(
        supabase,
        runAt,
        lookbackMinutes,
      ),
      loadRetryablePushNotificationJobs(supabase),
      finalizeExpiredStoryCardsSafely(supabase, runAt),
    ]);
    const finalizedStoryCardGroups = storyCardRollover.finalizedCount;
    const notificationCount = deliveryJobs.length +
      questionJobs.length +
      calendarJobs.length +
      retryJobs.length;
    const processedCount = notificationCount + finalizedStoryCardGroups;

    if (notificationCount === 0) {
      return jsonResponse({
        status: 'ok',
        runAt: runAt.toISOString(),
        lookbackMinutes,
        processedCount,
        finalizedStoryCardGroups,
        storyCardRolloverStatus: storyCardRollover.status,
      });
    }

    const accessToken = await createFcmAccessToken();
    const [
      deliveryResults,
      questionResults,
      calendarResults,
      retryResults,
    ] = await Promise.all([
      dispatchDailyQuestionDeliveryJobs(
        deliveryJobs,
        { supabase, accessToken },
      ),
      dispatchUnansweredQuestionReminderJobs(
        questionJobs,
        { supabase, accessToken },
      ),
      dispatchCalendarEventReminderJobs(
        calendarJobs,
        { supabase, accessToken },
      ),
      dispatchRetryablePushNotificationJobs(
        retryJobs,
        { supabase, accessToken },
      ),
    ]);

    return jsonResponse({
      status: 'ok',
      runAt: runAt.toISOString(),
      lookbackMinutes,
      processedCount,
      finalizedStoryCardGroups,
      storyCardRolloverStatus: storyCardRollover.status,
      results: [
        ...deliveryResults,
        ...questionResults,
        ...calendarResults,
        ...retryResults,
      ],
    });
  } catch (error) {
    return internalErrorResponse(
      'scheduled_notification_dispatch_failed',
      error,
    );
  }
});

async function parseRequestBody(
  request: Request,
): Promise<Record<string, unknown>> {
  const text = await request.text();
  if (text.trim() === '') {
    return {};
  }

  const parsed = JSON.parse(text);
  return typeof parsed === 'object' && parsed !== null
    ? parsed as Record<string, unknown>
    : {};
}

function normalizeLookbackMinutes(value: unknown) {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return defaultLookbackMinutes;
  }

  return Math.min(Math.max(Math.floor(value), 1), 60);
}

function normalizeRunAt(value: unknown) {
  if (typeof value !== 'string' || value.trim() === '') {
    return new Date();
  }

  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? new Date() : parsed;
}
