alter table public.ai_processing_jobs
  drop constraint ai_processing_jobs_type_check;

alter table public.ai_processing_jobs
  add constraint ai_processing_jobs_type_check
    check (
      job_type in (
        'extract_memories',
        'generate_feedback',
        'select_curated_question',
        'generate_general_question',
        'generate_personalized_question',
        'rebuild_profile'
      )
    );

alter table public.ai_runs
  drop constraint ai_runs_task_check;

alter table public.ai_runs
  add constraint ai_runs_task_check
    check (
      task in (
        'extract_memories',
        'generate_feedback',
        'select_curated_question',
        'generate_general_question',
        'generate_personalized_question',
        'rebuild_profile'
      )
    );

create or replace function private.ai_processing_job_priority(
  requested_job_type text
)
returns smallint
language sql
immutable
strict
set search_path = ''
as $$
  select (
    case requested_job_type
      when 'rebuild_profile' then 0
      when 'generate_feedback' then 10
      when 'select_curated_question' then 20
      when 'generate_general_question' then 20
      when 'generate_personalized_question' then 20
      when 'extract_memories' then 30
      else 100
    end
  )::smallint;
$$;

create or replace function private.enqueue_ai_processing_job_source(
  requested_couple_id uuid,
  requested_daily_question_id uuid,
  requested_focused_question_id uuid,
  requested_job_type text,
  requested_deduplication_key text,
  requested_available_at timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_job_type text := btrim(requested_job_type);
  normalized_deduplication_key text := btrim(requested_deduplication_key);
  target_job_id uuid;
begin
  if requested_couple_id is null
    or normalized_job_type is null
    or normalized_job_type not in (
      'extract_memories',
      'generate_feedback',
      'select_curated_question',
      'generate_general_question',
      'generate_personalized_question',
      'rebuild_profile'
    )
    or normalized_deduplication_key is null
    or char_length(normalized_deduplication_key) not between 1 and 300
    or (
      normalized_job_type = 'rebuild_profile'
      and num_nonnulls(
        requested_daily_question_id,
        requested_focused_question_id
      ) <> 0
    )
    or (
      normalized_job_type <> 'rebuild_profile'
      and num_nonnulls(
        requested_daily_question_id,
        requested_focused_question_id
      ) <> 1
    )
  then
    perform private.raise_app_error('invalid_ai_job');
  end if;

  if not private.have_all_couple_members_granted_ai_consent(
    requested_couple_id
  ) then
    return null;
  end if;

  if requested_daily_question_id is not null
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.id = requested_daily_question_id
        and dq.couple_id = requested_couple_id
        and dq.status = 'completed'
    )
  then
    perform private.raise_app_error('invalid_ai_job_question');
  end if;

  if requested_focused_question_id is not null
    and not exists (
      select 1
      from public.ai_focused_questions as aifq
      where aifq.id = requested_focused_question_id
        and aifq.couple_id = requested_couple_id
        and aifq.status = 'completed'
    )
  then
    perform private.raise_app_error('invalid_ai_job_question');
  end if;

  insert into public.ai_processing_jobs (
    couple_id,
    daily_question_id,
    focused_question_id,
    job_type,
    deduplication_key,
    available_at
  )
  values (
    requested_couple_id,
    requested_daily_question_id,
    requested_focused_question_id,
    normalized_job_type,
    normalized_deduplication_key,
    coalesce(requested_available_at, now())
  )
  on conflict (deduplication_key) do nothing
  returning id into target_job_id;

  if target_job_id is null then
    select aipj.id
    into target_job_id
    from public.ai_processing_jobs as aipj
    where aipj.deduplication_key = normalized_deduplication_key;
  end if;

  return target_job_id;
end;
$$;

revoke execute on function private.enqueue_ai_processing_job_source(
  uuid,
  uuid,
  uuid,
  text,
  text,
  timestamptz
) from public, anon, authenticated;

alter function public.get_ai_processing_job_context(uuid)
  rename to get_ai_processing_job_context_with_answers_v5;

revoke execute on function public.get_ai_processing_job_context_with_answers_v5(
  uuid
) from public, anon, authenticated, service_role;

create or replace function public.get_ai_processing_job_context(
  requested_job_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.ai_processing_jobs as aipj
    where aipj.id = requested_job_id
      and aipj.job_type = 'generate_general_question'
  ) then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  return public.get_ai_processing_job_context_with_answers_v5(
    requested_job_id
  );
end;
$$;

create or replace function public.get_ai_general_question_job_context(
  requested_job_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_job public.ai_processing_jobs%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  completed_foundation_count integer;
  recent_questions_json jsonb;
begin
  if requested_job_id is null then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = requested_job_id
  for update;

  if not found
    or target_job.job_type <> 'generate_general_question'
    or target_job.status <> 'processing'
    or num_nonnulls(
      target_job.daily_question_id,
      target_job.focused_question_id
    ) <> 1
    or target_job.claimed_by is null
    or target_job.lease_expires_at is null
    or target_job.lease_expires_at <= now()
    or not private.have_all_couple_members_granted_ai_consent(
      target_job.couple_id
    )
  then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  if target_job.daily_question_id is not null
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.id = target_job.daily_question_id
        and dq.couple_id = target_job.couple_id
        and dq.status = 'completed'
    )
  then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  if target_job.focused_question_id is not null
    and not exists (
      select 1
      from public.ai_focused_questions as aifq
      where aifq.id = target_job.focused_question_id
        and aifq.couple_id = target_job.couple_id
        and aifq.status = 'completed'
    )
  then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if not found then
    perform private.raise_app_error('ai_curriculum_unavailable');
  end if;

  select count(*)::integer
  into completed_foundation_count
  from private.completed_ai_foundation_question_ids(
    target_job.couple_id,
    active_curriculum.version
  );

  if completed_foundation_count
    < greatest(active_curriculum.question_count - 2, 0)
  then
    perform private.raise_app_error('ai_foundation_incomplete');
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question_key', recent.question_key,
        'text', recent.question_text,
        'category', recent.category,
        'mood', recent.mood,
        'domain', recent.learning_domain
      )
      order by recent.completed_at desc, recent.instance_id
    ),
    '[]'::jsonb
  )
  into recent_questions_json
  from (
    select *
    from (
      select
        dq.id as instance_id,
        greatest(dq.updated_at, dq.created_at) as completed_at,
        q.question_key,
        q.question_text,
        q.category,
        q.mood,
        q.learning_domain
      from public.daily_questions as dq
      join public.questions as q on q.id = dq.question_id
      where dq.couple_id = target_job.couple_id
        and dq.status = 'completed'

      union all

      select
        aifq.id,
        greatest(aifq.updated_at, aifq.created_at),
        q.question_key,
        q.question_text,
        q.category,
        q.mood,
        q.learning_domain
      from public.ai_focused_questions as aifq
      join public.questions as q on q.id = aifq.question_id
      where aifq.couple_id = target_job.couple_id
        and aifq.status = 'completed'
    ) as completed_questions
    order by completed_at desc, instance_id
    limit 12
  ) as recent;

  return jsonb_build_object(
    'foundation_progress', jsonb_build_object(
      'completed_count', completed_foundation_count,
      'total_count', active_curriculum.question_count
    ),
    'recent_questions', recent_questions_json
  );
end;
$$;

revoke execute on function public.get_ai_processing_job_context(uuid)
  from public, anon, authenticated;
revoke execute on function public.get_ai_general_question_job_context(uuid)
  from public, anon, authenticated;
grant execute on function public.get_ai_processing_job_context(uuid)
  to service_role;
grant execute on function public.get_ai_general_question_job_context(uuid)
  to service_role;
