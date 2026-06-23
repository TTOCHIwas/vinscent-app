import {
  createFcmAccessToken,
  createServiceRoleClient,
  jsonResponse,
  sendPushNotification,
  verifyWebhookSecret,
} from '../_shared/push.ts';

type ActiveCoupleRow = {
  id: string;
  user_a_id: string;
  user_b_id: string;
  relationship_start_date: string | null;
  timezone: string;
};

type PreferenceRow = {
  user_id: string;
  daily_question_enabled: boolean;
  reminder_enabled: boolean;
  daily_question_delivery_time: string;
};

type DailyQuestionRow = {
  daily_question_id: string;
  couple_id: string;
  question_id: string;
  assigned_date: string;
  status: string;
};

type AnswerStateRow = {
  daily_question_id: string;
  user_id: string;
};

type ScheduledJob = {
  notificationType: 'daily_question_delivery' | 'unanswered_reminder';
  sourceId: string;
  coupleId: string;
  receiverUserId: string;
  assignedDate: string;
};

const defaultDeliveryTime = '09:00:00';
const defaultLookbackMinutes = 10;

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'SCHEDULE_WEBHOOK_SECRET',
      headerName: 'x-schedule-webhook-secret',
      fallbackEnvName: 'EXPRESSION_WEBHOOK_SECRET',
      fallbackHeaderName: 'x-expression-webhook-secret',
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
    const couples = await loadActiveCouples(supabase);
    if (couples.length === 0) {
      return jsonResponse({
        status: 'ok',
        runAt: runAt.toISOString(),
        lookbackMinutes,
        processedCount: 0,
      });
    }

    const preferencesByUserId = await loadPreferencesByUserId(
      supabase,
      couples,
    );

    const pendingJobs = buildPendingJobs(
      couples,
      preferencesByUserId,
      runAt,
      lookbackMinutes,
    );
    if (pendingJobs.length === 0) {
      return jsonResponse({
        status: 'ok',
        runAt: runAt.toISOString(),
        lookbackMinutes,
        processedCount: 0,
      });
    }

    const jobs = await hydrateJobsWithQuestionIds(supabase, pendingJobs);
    if (jobs.length === 0) {
      return jsonResponse({
        status: 'ok',
        runAt: runAt.toISOString(),
        lookbackMinutes,
        processedCount: 0,
      });
    }

    const filteredJobs = await filterReminderTargets(supabase, jobs);
    if (filteredJobs.length === 0) {
      return jsonResponse({
        status: 'ok',
        runAt: runAt.toISOString(),
        lookbackMinutes,
        processedCount: 0,
      });
    }

    const accessToken = await createFcmAccessToken();
    const results = [];

    for (const job of filteredJobs) {
      const result = await sendPushNotification({
        supabase,
        notificationType: job.notificationType,
        sourceId: job.sourceId,
        receiverUserId: job.receiverUserId,
        title: 'Vinscent',
        body: notificationBodyFor(job.notificationType),
        accessToken,
        data: {
          daily_question_id: job.sourceId,
          couple_id: job.coupleId,
          assigned_date: job.assignedDate,
        },
      });
      results.push({ notificationType: job.notificationType, ...result });
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

async function loadActiveCouples(
  supabase: ReturnType<typeof createServiceRoleClient>,
) {
  const { data, error } = await supabase
    .from('couples')
    .select('id, user_a_id, user_b_id, relationship_start_date, timezone')
    .eq('status', 'active')
    .not('relationship_start_date', 'is', null);

  if (error) {
    throw new Error(`active_couple_query_failed:${error.message}`);
  }

  return (data ?? []) as ActiveCoupleRow[];
}

async function loadPreferencesByUserId(
  supabase: ReturnType<typeof createServiceRoleClient>,
  couples: ActiveCoupleRow[],
) {
  const userIds = Array.from(
    new Set(couples.flatMap((couple) => [couple.user_a_id, couple.user_b_id])),
  );
  const { data, error } = await supabase
    .from('user_notification_preferences')
    .select(
      'user_id, daily_question_enabled, reminder_enabled, daily_question_delivery_time',
    )
    .in('user_id', userIds);

  if (error) {
    throw new Error(`notification_preference_query_failed:${error.message}`);
  }

  const preferences = new Map<string, PreferenceRow>();
  for (const row of (data ?? []) as PreferenceRow[]) {
    preferences.set(row.user_id, row);
  }

  return preferences;
}

function buildPendingJobs(
  couples: ActiveCoupleRow[],
  preferencesByUserId: Map<string, PreferenceRow>,
  runAt: Date,
  lookbackMinutes: number,
) {
  const jobs: Array<{
    notificationType: 'daily_question_delivery' | 'unanswered_reminder';
    coupleId: string;
    receiverUserId: string;
    assignedDate: string;
  }> = [];

  for (const couple of couples) {
    const localClock = getLocalClock(runAt, couple.timezone);
    const relationshipStartDate = couple.relationship_start_date;
    if (!relationshipStartDate) {
      continue;
    }

    for (const receiverUserId of [couple.user_a_id, couple.user_b_id]) {
      const preference = preferencesByUserId.get(receiverUserId);
      const deliveryTime = parseTimeToMinutes(
        preference?.daily_question_delivery_time ?? defaultDeliveryTime,
      );
      const deliveryDueDate = resolveDueDate(
        localClock.date,
        localClock.minutes,
        deliveryTime,
        lookbackMinutes,
      );

      if (
        (preference?.daily_question_enabled ?? true) &&
        deliveryDueDate !== null &&
        deliveryDueDate >= relationshipStartDate
      ) {
        jobs.push({
          notificationType: 'daily_question_delivery',
          coupleId: couple.id,
          receiverUserId,
          assignedDate: deliveryDueDate,
        });
      }

      const reminderDueDate = resolveDueDate(
        localClock.date,
        localClock.minutes,
        getReminderMinutes(deliveryTime),
        lookbackMinutes,
      );
      const reminderDate = reminderDueDate === null
        ? null
        : getReminderAssignedDate(reminderDueDate, deliveryTime);

      if (
        (preference?.reminder_enabled ?? true) &&
        reminderDate !== null &&
        reminderDate >= relationshipStartDate
      ) {
        jobs.push({
          notificationType: 'unanswered_reminder',
          coupleId: couple.id,
          receiverUserId,
          assignedDate: reminderDate,
        });
      }
    }
  }

  return jobs;
}

async function hydrateJobsWithQuestionIds(
  supabase: ReturnType<typeof createServiceRoleClient>,
  pendingJobs: Array<{
    notificationType: 'daily_question_delivery' | 'unanswered_reminder';
    coupleId: string;
    receiverUserId: string;
    assignedDate: string;
  }>,
): Promise<ScheduledJob[]> {
  const dailyQuestionIds = new Map<string, string>();

  for (const job of pendingJobs) {
    const cacheKey = `${job.coupleId}:${job.assignedDate}`;
    if (!dailyQuestionIds.has(cacheKey)) {
      const { data, error } = await supabase
        .rpc('get_or_assign_daily_question_for_couple', {
          requested_couple_id: job.coupleId,
          requested_target_date: job.assignedDate,
        })
        .single();

      if (error) {
        throw new Error(`daily_question_assign_failed:${error.message}`);
      }

      const row = data as DailyQuestionRow | null;
      if (!row?.daily_question_id) {
        throw new Error('daily_question_assign_missing');
      }

      dailyQuestionIds.set(cacheKey, row.daily_question_id);
    }
  }

  return pendingJobs.map((job) => ({
    notificationType: job.notificationType,
    sourceId: dailyQuestionIds.get(`${job.coupleId}:${job.assignedDate}`)!,
    coupleId: job.coupleId,
    receiverUserId: job.receiverUserId,
    assignedDate: job.assignedDate,
  }));
}

async function filterReminderTargets(
  supabase: ReturnType<typeof createServiceRoleClient>,
  jobs: ScheduledJob[],
) {
  const reminderJobs = jobs.filter(
    (job) => job.notificationType === 'unanswered_reminder',
  );
  if (reminderJobs.length === 0) {
    return jobs;
  }

  const questionIds = Array.from(
    new Set(reminderJobs.map((job) => job.sourceId)),
  );
  const { data, error } = await supabase
    .from('daily_question_answers')
    .select('daily_question_id, user_id')
    .in('daily_question_id', questionIds);

  if (error) {
    throw new Error(`daily_question_answer_query_failed:${error.message}`);
  }

  const answeredPairs = new Set(
    ((data ?? []) as AnswerStateRow[]).map(
      (row) => `${row.daily_question_id}:${row.user_id}`,
    ),
  );

  return jobs.filter((job) => {
    if (job.notificationType !== 'unanswered_reminder') {
      return true;
    }

    return !answeredPairs.has(`${job.sourceId}:${job.receiverUserId}`);
  });
}

function notificationBodyFor(
  notificationType: ScheduledJob['notificationType'],
) {
  return notificationType === 'daily_question_delivery'
    ? '오늘 질문이 도착했어요.'
    : '아직 오늘 질문에 답변하지 않았어요.';
}

function parseTimeToMinutes(value: string) {
  const parts = value.split(':');
  if (parts.length < 2) {
    return parseTimeToMinutes(defaultDeliveryTime);
  }

  const hour = Number.parseInt(parts[0], 10);
  const minute = Number.parseInt(parts[1], 10);
  return hour * 60 + minute;
}

function getReminderMinutes(deliveryMinutes: number) {
  return (deliveryMinutes + 60) % (24 * 60);
}

function resolveDueDate(
  localDate: string,
  localMinutes: number,
  targetMinutes: number,
  lookbackMinutes: number,
) {
  if (
    localMinutes >= targetMinutes &&
    localMinutes < targetMinutes + lookbackMinutes
  ) {
    return localDate;
  }

  const wrappedWindowEnd = targetMinutes + lookbackMinutes - (24 * 60);
  if (
    targetMinutes + lookbackMinutes > 24 * 60 &&
    localMinutes < wrappedWindowEnd
  ) {
    return addDays(localDate, -1);
  }

  return null;
}

function getReminderAssignedDate(localDate: string, deliveryMinutes: number) {
  if (deliveryMinutes + 60 < 24 * 60) {
    return localDate;
  }

  return addDays(localDate, -1);
}

function getLocalClock(date: Date, timeZone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(date);

  const map = new Map(parts.map((part) => [part.type, part.value]));
  const year = map.get('year')!;
  const month = map.get('month')!;
  const day = map.get('day')!;
  const hour = Number.parseInt(map.get('hour')!, 10);
  const minute = Number.parseInt(map.get('minute')!, 10);

  return {
    date: `${year}-${month}-${day}`,
    minutes: hour * 60 + minute,
  };
}

function addDays(date: string, deltaDays: number) {
  const baseDate = new Date(`${date}T00:00:00Z`);
  baseDate.setUTCDate(baseDate.getUTCDate() + deltaDays);
  return baseDate.toISOString().slice(0, 10);
}
