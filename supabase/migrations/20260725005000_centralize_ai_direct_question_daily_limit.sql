create or replace function private.ai_direct_question_daily_limit()
returns smallint
language sql
immutable
parallel safe
set search_path = ''
as $$
  select 100::smallint;
$$;

revoke execute on function private.ai_direct_question_daily_limit()
  from public, anon, authenticated;

alter table public.ai_user_question_daily_usage
  drop constraint ai_user_question_daily_usage_count_check;

alter table public.ai_user_question_daily_usage
  add constraint ai_user_question_daily_usage_count_check
    check (submission_count >= 0);

create or replace function public.submit_ai_user_question(
  requested_question_text text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  normalized_question text := btrim(requested_question_text);
  current_couple_date date;
  submitted_today_count smallint;
  daily_question_limit smallint :=
    private.ai_direct_question_daily_limit();
  created_question public.ai_user_questions%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.is_ai_personalization_enabled(active_couple.id) then
    perform private.raise_app_error('ai_personalization_not_ready');
  end if;

  if normalized_question is null or char_length(normalized_question) = 0 then
    perform private.raise_app_error('question_required');
  end if;

  if char_length(normalized_question) > 300 then
    perform private.raise_app_error('question_too_long');
  end if;

  if private.ai_question_contains_blocked_topic(normalized_question) then
    perform private.raise_app_error('ai_sensitive_question_not_available');
  end if;

  current_couple_date := private.current_date_in_timezone(
    active_couple.timezone
  );

  insert into public.ai_user_question_daily_usage (
    couple_id,
    user_id,
    context_date,
    submission_count
  )
  values (
    active_couple.id,
    current_user_id,
    current_couple_date,
    1
  )
  on conflict (couple_id, user_id, context_date)
  do update
  set submission_count =
    public.ai_user_question_daily_usage.submission_count + 1
  where public.ai_user_question_daily_usage.submission_count
    < daily_question_limit
  returning submission_count into submitted_today_count;

  if not found then
    perform private.raise_app_error('ai_daily_question_limit_reached');
  end if;

  insert into public.ai_user_questions (
    couple_id,
    requester_user_id,
    question_text
  )
  values (
    active_couple.id,
    current_user_id,
    normalized_question
  )
  returning * into created_question;

  insert into public.ai_processing_jobs (
    couple_id,
    user_question_id,
    job_type,
    deduplication_key,
    max_attempts
  )
  values (
    active_couple.id,
    created_question.id,
    'answer_user_question',
    'direct-question:' || created_question.id::text,
    5
  );

  return jsonb_build_object(
    'question', jsonb_build_object(
      'id', created_question.id,
      'question_text', created_question.question_text,
      'status', created_question.status,
      'answer_text', created_question.answer_text,
      'failure_code', created_question.failure_code,
      'created_at', created_question.created_at,
      'answered_at', created_question.answered_at
    ),
    'daily_limit', daily_question_limit,
    'remaining_count', greatest(
      0,
      daily_question_limit - submitted_today_count
    )
  );
end;
$$;

create or replace function public.get_my_ai_user_questions()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  current_couple_date date;
  submitted_today_count smallint;
  daily_question_limit smallint :=
    private.ai_direct_question_daily_limit();
  questions_json jsonb;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.is_ai_personalization_enabled(active_couple.id) then
    perform private.raise_app_error('ai_personalization_not_ready');
  end if;

  current_couple_date := private.current_date_in_timezone(
    active_couple.timezone
  );

  select coalesce(aiuqdu.submission_count, 0)
  into submitted_today_count
  from (
    select 1
  ) as fallback
  left join public.ai_user_question_daily_usage as aiuqdu
    on aiuqdu.couple_id = active_couple.id
    and aiuqdu.user_id = current_user_id
    and aiuqdu.context_date = current_couple_date;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', recent.id,
        'question_text', recent.question_text,
        'status', recent.status,
        'result_kind', recent.result_kind,
        'answer_text', recent.answer_text,
        'failure_code', recent.failure_code,
        'created_at', recent.created_at,
        'answered_at', recent.answered_at,
        'follow_up', case
          when recent.follow_up_id is null then null
          else jsonb_build_object(
            'id', recent.follow_up_id,
            'question_text', recent.follow_up_question_text,
            'status', recent.follow_up_status,
            'shared_question_id', recent.shared_question_id
          )
        end
      )
      order by recent.created_at desc, recent.id desc
    ),
    '[]'::jsonb
  )
  into questions_json
  from (
    select
      aiuq.*,
      aiuqfu.id as follow_up_id,
      aiuqfu.question_text as follow_up_question_text,
      aiuqfu.status as follow_up_status,
      aiuqfu.shared_question_id
    from public.ai_user_questions as aiuq
    left join public.ai_user_question_follow_ups as aiuqfu
      on aiuqfu.user_question_id = aiuq.id
    where aiuq.couple_id = active_couple.id
      and aiuq.requester_user_id = current_user_id
    order by aiuq.created_at desc, aiuq.id desc
    limit 30
  ) as recent;

  return jsonb_build_object(
    'daily_limit', daily_question_limit,
    'remaining_count', greatest(
      0,
      daily_question_limit - submitted_today_count
    ),
    'questions', questions_json
  );
end;
$$;

revoke execute on function public.submit_ai_user_question(text)
  from public, anon;
revoke execute on function public.get_my_ai_user_questions()
  from public, anon;
grant execute on function public.submit_ai_user_question(text)
  to authenticated;
grant execute on function public.get_my_ai_user_questions()
  to authenticated;
