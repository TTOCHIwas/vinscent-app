import { appDisplayName } from '../_shared/app_brand.ts';
import { sendPushNotification } from '../_shared/push.ts';
import type { createServiceRoleClient } from '../_shared/supabase.ts';
import { dispatchInBatches } from './dispatch_in_batches.ts';

type DailyQuestionDeliveryJob = {
  dailyQuestionId: string;
  coupleId: string;
  receiverUserId: string;
  assignedDate: string;
};

type DailyQuestionDeliveryRow = {
  daily_question_id: string;
  couple_id: string;
  receiver_user_id: string;
  assigned_date: string;
};

type DailyQuestionDeliveryHandlerParams = {
  supabase: ReturnType<typeof createServiceRoleClient>;
  accessToken: string;
};

const assignmentBatchSize = 100;
const dispatchConcurrency = 4;

export async function loadDueDailyQuestionDeliveryJobs(
  supabase: ReturnType<typeof createServiceRoleClient>,
  runAt: Date,
) {
  const { data, error } = await supabase.rpc(
    'assign_due_daily_questions',
    {
      requested_run_at: runAt.toISOString(),
      requested_limit: assignmentBatchSize,
    },
  );

  if (error) {
    throw new Error(`daily_question_assignment_failed:${error.message}`);
  }

  return ((data ?? []) as DailyQuestionDeliveryRow[]).map((row) => ({
    dailyQuestionId: row.daily_question_id,
    coupleId: row.couple_id,
    receiverUserId: row.receiver_user_id,
    assignedDate: row.assigned_date,
  }));
}

export function dispatchDailyQuestionDeliveryJobs(
  jobs: DailyQuestionDeliveryJob[],
  params: DailyQuestionDeliveryHandlerParams,
) {
  return dispatchInBatches(jobs, dispatchConcurrency, async (job) => {
    const result = await sendPushNotification({
      supabase: params.supabase,
      notificationType: 'daily_question_delivery',
      sourceId: job.dailyQuestionId,
      receiverUserId: job.receiverUserId,
      title: appDisplayName,
      body: '오늘 질문이 도착했어요.',
      accessToken: params.accessToken,
      preferenceColumn: 'daily_question_enabled',
      data: {
        daily_question_id: job.dailyQuestionId,
        couple_id: job.coupleId,
        assigned_date: job.assignedDate,
      },
    });
    return { notificationType: 'daily_question_delivery', ...result };
  });
}
