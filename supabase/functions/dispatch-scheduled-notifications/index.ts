import { createFcmAccessToken } from '../_shared/fcm.ts';
import { sendPushNotification } from '../_shared/push.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';
import {
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';

type StoryLoopRow = {
  id: string;
  couple_id: string;
  couple_date: string;
  question_generated_at: string;
};

type DailyQuestionRow = {
  id: string;
  couple_id: string;
  story_loop_id: string;
};

type CoupleRow = {
  id: string;
  user_a_id: string;
  user_b_id: string;
};

type PreferenceRow = {
  user_id: string;
  reminder_enabled: boolean;
};

type AnswerStateRow = {
  daily_question_id: string;
  user_id: string;
};

type ReminderJob = {
  dailyQuestionId: string;
  coupleId: string;
  receiverUserId: string;
  assignedDate: string;
};

const defaultLookbackMinutes = 10;
const reminderDelayMinutes = 60;

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
    const jobs = await loadDueReminderJobs(supabase, runAt, lookbackMinutes);
    if (jobs.length === 0) {
      return jsonResponse({
        status: 'ok',
        runAt: runAt.toISOString(),
        lookbackMinutes,
        processedCount: 0,
      });
    }

    const accessToken = await createFcmAccessToken();
    const results = [];

    for (const job of jobs) {
      const result = await sendPushNotification({
        supabase,
        notificationType: 'unanswered_reminder',
        sourceId: job.dailyQuestionId,
        receiverUserId: job.receiverUserId,
        title: 'Vinscent',
        body: '아직 오늘 질문에 답변하지 않았어요.',
        accessToken,
        data: {
          daily_question_id: job.dailyQuestionId,
          couple_id: job.coupleId,
          assigned_date: job.assignedDate,
        },
      });
      results.push({ notificationType: 'unanswered_reminder', ...result });
    }

    return jsonResponse({
      status: 'ok',
      runAt: runAt.toISOString(),
      lookbackMinutes,
      processedCount: results.length,
      results,
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

async function loadDueReminderJobs(
  supabase: ReturnType<typeof createServiceRoleClient>,
  runAt: Date,
  lookbackMinutes: number,
) {
  const dueLoopStart = new Date(
    runAt.getTime() - (reminderDelayMinutes + lookbackMinutes) * 60_000,
  );
  const dueLoopEnd = new Date(
    runAt.getTime() - reminderDelayMinutes * 60_000,
  );
  const { data: loopData, error: loopError } = await supabase
    .from('daily_story_loops')
    .select('id, couple_id, couple_date, question_generated_at')
    .in('status', ['question_generated', 'answered_by_one'])
    .gte('question_generated_at', dueLoopStart.toISOString())
    .lt('question_generated_at', dueLoopEnd.toISOString());

  if (loopError) {
    throw new Error(`due_story_loop_query_failed:${loopError.message}`);
  }

  const loops = (loopData ?? []) as StoryLoopRow[];
  if (loops.length === 0) {
    return [] as ReminderJob[];
  }

  const loopIds = loops.map((loop) => loop.id);
  const { data: questionData, error: questionError } = await supabase
    .from('daily_questions')
    .select('id, couple_id, story_loop_id')
    .in('story_loop_id', loopIds);

  if (questionError) {
    throw new Error(`story_loop_question_query_failed:${questionError.message}`);
  }

  const questionsByLoopId = new Map(
    ((questionData ?? []) as DailyQuestionRow[]).map((question) => [
      question.story_loop_id,
      question,
    ]),
  );
  const dueLoops = loops.filter((loop) => questionsByLoopId.has(loop.id));
  if (dueLoops.length === 0) {
    return [] as ReminderJob[];
  }

  const coupleIds = Array.from(new Set(dueLoops.map((loop) => loop.couple_id)));
  const { data: coupleData, error: coupleError } = await supabase
    .from('couples')
    .select('id, user_a_id, user_b_id')
    .in('id', coupleIds)
    .eq('status', 'active');

  if (coupleError) {
    throw new Error(`reminder_couple_query_failed:${coupleError.message}`);
  }

  const couplesById = new Map(
    ((coupleData ?? []) as CoupleRow[]).map((couple) => [couple.id, couple]),
  );
  const userIds = Array.from(
    new Set(
      [...couplesById.values()].flatMap((couple) => [
        couple.user_a_id,
        couple.user_b_id,
      ]),
    ),
  );
  const preferencesByUserId = await loadPreferencesByUserId(supabase, userIds);

  const questionIds = Array.from(
    new Set(
      dueLoops.map((loop) => questionsByLoopId.get(loop.id)!.id),
    ),
  );
  const { data: answerData, error: answerError } = await supabase
    .from('daily_question_answers')
    .select('daily_question_id, user_id')
    .in('daily_question_id', questionIds);

  if (answerError) {
    throw new Error(`daily_question_answer_query_failed:${answerError.message}`);
  }

  const answeredPairs = new Set(
    ((answerData ?? []) as AnswerStateRow[]).map(
      (answer) => `${answer.daily_question_id}:${answer.user_id}`,
    ),
  );
  const jobs: ReminderJob[] = [];

  for (const loop of dueLoops) {
    const couple = couplesById.get(loop.couple_id);
    const question = questionsByLoopId.get(loop.id);
    if (!couple || !question) {
      continue;
    }

    for (const receiverUserId of [couple.user_a_id, couple.user_b_id]) {
      if (preferencesByUserId.get(receiverUserId)?.reminder_enabled === false) {
        continue;
      }

      if (answeredPairs.has(`${question.id}:${receiverUserId}`)) {
        continue;
      }

      jobs.push({
        dailyQuestionId: question.id,
        coupleId: couple.id,
        receiverUserId,
        assignedDate: loop.couple_date,
      });
    }
  }

  return jobs;
}

async function loadPreferencesByUserId(
  supabase: ReturnType<typeof createServiceRoleClient>,
  userIds: string[],
) {
  if (userIds.length === 0) {
    return new Map<string, PreferenceRow>();
  }

  const { data, error } = await supabase
    .from('user_notification_preferences')
    .select('user_id, reminder_enabled')
    .in('user_id', userIds);

  if (error) {
    throw new Error(`notification_preference_query_failed:${error.message}`);
  }

  return new Map(
    ((data ?? []) as PreferenceRow[]).map((preference) => [
      preference.user_id,
      preference,
    ]),
  );
}
