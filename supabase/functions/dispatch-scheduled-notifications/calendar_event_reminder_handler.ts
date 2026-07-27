import { appDisplayName } from '../_shared/app_brand.ts';
import { sendPushNotification } from '../_shared/push.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';
import { buildCalendarEventReminderBody } from './calendar_event_reminder_message.ts';
import { dispatchInBatches } from './dispatch_in_batches.ts';

type CalendarEventReminderRow = {
  source_id: string;
  event_id: string;
  couple_id: string;
  receiver_user_id: string;
  title: string;
  occurrence_date: string;
  offset_days: number;
  scheduled_at: string;
};

type CalendarEventReminderHandlerParams = {
  supabase: ReturnType<typeof createServiceRoleClient>;
  accessToken: string;
};

const calendarReminderBatchSize = 100;
const dispatchConcurrency = 4;

export async function loadDueCalendarEventReminderJobs(
  supabase: ReturnType<typeof createServiceRoleClient>,
  runAt: Date,
  lookbackMinutes: number,
) {
  const { data, error } = await supabase.rpc(
    'get_due_couple_calendar_event_reminders',
    {
      requested_run_at: runAt.toISOString(),
      requested_lookback_minutes: lookbackMinutes,
      requested_limit: calendarReminderBatchSize,
    },
  );

  if (error) {
    throw new Error(`calendar_event_reminder_query_failed:${error.message}`);
  }

  return (data ?? []) as CalendarEventReminderRow[];
}

export async function dispatchCalendarEventReminderJobs(
  jobs: CalendarEventReminderRow[],
  params: CalendarEventReminderHandlerParams,
) {
  return dispatchInBatches(jobs, dispatchConcurrency, async (job) => {
    const result = await sendPushNotification({
      supabase: params.supabase,
      notificationType: 'calendar_event_reminder',
      sourceId: job.source_id,
      receiverUserId: job.receiver_user_id,
      title: appDisplayName,
      body: buildCalendarEventReminderBody(job.title, job.offset_days),
      accessToken: params.accessToken,
      data: {
        event_id: job.event_id,
        couple_id: job.couple_id,
        event_date: job.occurrence_date,
        route: `/calendar?date=${job.occurrence_date}`,
      },
    });
    return { notificationType: 'calendar_event_reminder', ...result };
  });
}
