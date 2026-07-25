import { createFcmAccessToken } from '../_shared/fcm.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';
import {
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';
import {
  dispatchCalendarEventReminderJobs,
  loadDueCalendarEventReminderJobs,
} from './calendar_event_reminder_handler.ts';
import {
  dispatchUnansweredQuestionReminderJobs,
  loadDueUnansweredQuestionReminderJobs,
} from './unanswered_question_reminder_handler.ts';

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

  const requestBody = await parseRequestBody(request);
  const lookbackMinutes = normalizeLookbackMinutes(
    requestBody.lookback_minutes,
  );
  const runAt = normalizeRunAt(requestBody.run_at);

  try {
    const supabase = createServiceRoleClient();
    const [questionJobs, calendarJobs] = await Promise.all([
      loadDueUnansweredQuestionReminderJobs(
        supabase,
        runAt,
        lookbackMinutes,
      ),
      loadDueCalendarEventReminderJobs(
        supabase,
        runAt,
        lookbackMinutes,
      ),
    ]);
    const processedCount = questionJobs.length + calendarJobs.length;

    if (processedCount === 0) {
      return jsonResponse({
        status: 'ok',
        runAt: runAt.toISOString(),
        lookbackMinutes,
        processedCount: 0,
      });
    }

    const accessToken = await createFcmAccessToken();
    const questionResults = await dispatchUnansweredQuestionReminderJobs(
      questionJobs,
      { supabase, accessToken },
    );
    const calendarResults = await dispatchCalendarEventReminderJobs(
      calendarJobs,
      { supabase, accessToken },
    );

    return jsonResponse({
      status: 'ok',
      runAt: runAt.toISOString(),
      lookbackMinutes,
      processedCount,
      results: [...questionResults, ...calendarResults],
    });
  } catch (error) {
    return jsonResponse(
      { error: 'scheduled_notification_dispatch_failed', detail: String(error) },
      500,
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
