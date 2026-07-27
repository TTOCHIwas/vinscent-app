import { sendPushNotification } from '../_shared/push.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';
import { dispatchInBatches } from './dispatch_in_batches.ts';

type ReminderJob = {
  dailyQuestionId: string;
  coupleId: string;
  receiverUserId: string;
  assignedDate: string;
};

type UnansweredQuestionReminderRow = {
  daily_question_id: string;
  couple_id: string;
  receiver_user_id: string;
  assigned_date: string;
};

type UnansweredQuestionReminderHandlerParams = {
  supabase: ReturnType<typeof createServiceRoleClient>;
  accessToken: string;
};

const reminderBatchSize = 100;
const dispatchConcurrency = 4;

export async function loadDueUnansweredQuestionReminderJobs(
  supabase: ReturnType<typeof createServiceRoleClient>,
  runAt: Date,
) {
  const { data, error } = await supabase.rpc(
    'get_due_unanswered_question_reminders',
    {
      requested_run_at: runAt.toISOString(),
      requested_limit: reminderBatchSize,
    },
  );

  if (error) {
    throw new Error(`unanswered_reminder_query_failed:${error.message}`);
  }

  return ((data ?? []) as UnansweredQuestionReminderRow[]).map((row) => ({
    dailyQuestionId: row.daily_question_id,
    coupleId: row.couple_id,
    receiverUserId: row.receiver_user_id,
    assignedDate: row.assigned_date,
  }));
}

export async function dispatchUnansweredQuestionReminderJobs(
  jobs: ReminderJob[],
  params: UnansweredQuestionReminderHandlerParams,
) {
  return dispatchInBatches(jobs, dispatchConcurrency, async (job) => {
    const result = await sendPushNotification({
      supabase: params.supabase,
      notificationType: 'unanswered_reminder',
      sourceId: job.dailyQuestionId,
      receiverUserId: job.receiverUserId,
      title: 'Vinscent',
      body: '아직 오늘 질문에 답변하지 않았어요.',
      accessToken: params.accessToken,
      preferenceColumn: 'reminder_enabled',
      data: {
        daily_question_id: job.dailyQuestionId,
        couple_id: job.coupleId,
        assigned_date: job.assignedDate,
      },
    });
    return { notificationType: 'unanswered_reminder', ...result };
  });
}
