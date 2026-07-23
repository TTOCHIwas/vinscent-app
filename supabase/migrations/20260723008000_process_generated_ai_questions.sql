alter function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) rename to succeed_ai_processing_run_without_generated_questions_v7;

revoke execute on function
  public.succeed_ai_processing_run_without_generated_questions_v7(
    uuid,
    jsonb,
    integer,
    integer,
    integer
  ) from public, anon, authenticated, service_role;

create or replace function private.succeed_ai_generated_question_run(
  requested_run_id uuid,
  requested_output jsonb,
  requested_input_token_count integer,
  requested_output_token_count integer,
  requested_latency_ms integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_run public.ai_runs%rowtype;
  target_job public.ai_processing_jobs%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  completed_foundation_count integer;
  normalized_question_key text := btrim(
    requested_output->>'question_key'
  );
  normalized_question_text text := btrim(
    requested_output->>'question_text'
  );
  normalized_category text := btrim(requested_output->>'category');
  normalized_mood text := nullif(btrim(requested_output->>'mood'), '');
  normalized_rationale text := btrim(requested_output->>'rationale');
  target_question_id uuid;
  recommendation_id uuid;
  completion_result boolean;
begin
  if requested_run_id is null
    or requested_output is null
    or jsonb_typeof(requested_output) <> 'object'
    or requested_input_token_count is not null
      and requested_input_token_count < 0
    or requested_output_token_count is not null
      and requested_output_token_count < 0
    or requested_latency_ms is not null
      and requested_latency_ms < 0
    or normalized_question_key is null
    or char_length(normalized_question_key) not between 1 and 120
    or normalized_question_text is null
    or char_length(normalized_question_text) not between 1 and 300
    or normalized_category is null
    or char_length(normalized_category) not between 1 and 100
    or normalized_mood is not null
      and char_length(normalized_mood) not between 1 and 100
    or normalized_rationale is null
    or char_length(normalized_rationale) not between 1 and 500
    or private.contains_blocked_ai_topic(normalized_question_text)
    or private.contains_blocked_ai_topic(normalized_category)
  then
    perform private.raise_app_error('invalid_ai_question_output');
  end if;

  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id
  for update;

  if not found
    or target_run.status <> 'started'
    or target_run.job_id is null
    or target_run.task not in (
      'generate_general_question',
      'generate_personalized_question'
    )
  then
    return false;
  end if;

  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = target_run.job_id
  for update;

  if not found
    or target_job.status <> 'processing'
    or target_job.lease_expires_at is null
    or target_job.lease_expires_at <= now()
    or target_job.couple_id <> target_run.couple_id
    or target_job.job_type <> target_run.task
    or not private.have_all_couple_members_granted_ai_consent(
      target_job.couple_id
    )
  then
    perform private.raise_app_error('invalid_ai_run_job');
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
    target_run.couple_id,
    active_curriculum.version
  );

  if target_run.task = 'generate_general_question' then
    if normalized_question_key
        !~ '^general_[a-z0-9_]+_[a-z0-9]{8}$'
      or completed_foundation_count
        < greatest(active_curriculum.question_count - 2, 0)
      or private.is_ai_personalization_enabled(target_run.couple_id)
    then
      perform private.raise_app_error('invalid_ai_question_output');
    end if;
  elsif normalized_question_key
      !~ '^personalized_[a-z0-9_]+_[a-z0-9]{8}$'
    or completed_foundation_count < active_curriculum.question_count
    or not private.is_ai_personalization_enabled(target_run.couple_id)
  then
    perform private.raise_app_error('invalid_ai_question_output');
  end if;

  update public.ai_runs as air
  set
    status = 'succeeded',
    input_token_count = requested_input_token_count,
    output_token_count = requested_output_token_count,
    latency_ms = requested_latency_ms,
    safety_status = 'passed',
    error_code = null,
    completed_at = now()
  where air.id = target_run.id;

  insert into public.questions (
    source,
    question_key,
    question_text,
    category,
    mood,
    is_active,
    personalized_for_couple_id,
    generated_by_run_id
  )
  values (
    'ai',
    normalized_question_key,
    normalized_question_text,
    normalized_category,
    normalized_mood,
    true,
    target_run.couple_id,
    target_run.id
  )
  returning id into target_question_id;

  perform pg_advisory_xact_lock(
    hashtext('ai_question_recommendation'),
    hashtext(target_run.couple_id::text)
  );

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  from public.ai_runs as source_run
  where aiqr.couple_id = target_run.couple_id
    and aiqr.status = 'pending'
    and source_run.id = aiqr.source_run_id
    and source_run.task in (
      'generate_general_question',
      'generate_personalized_question'
    )
    and source_run.task <> target_run.task;

  update public.questions as q
  set is_active = false
  where q.id in (
    select aiqr.question_id
    from public.ai_question_recommendations as aiqr
    join public.ai_runs as source_run on source_run.id = aiqr.source_run_id
    where aiqr.couple_id = target_run.couple_id
      and aiqr.status = 'expired'
      and source_run.task in (
        'generate_general_question',
        'generate_personalized_question'
      )
      and not exists (
        select 1
        from public.daily_questions as dq
        where dq.question_id = aiqr.question_id
      )
  );

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  where aiqr.id in (
    select pending.id
    from public.ai_question_recommendations as pending
    join public.ai_runs as source_run
      on source_run.id = pending.source_run_id
    where pending.couple_id = target_run.couple_id
      and pending.status = 'pending'
      and source_run.task = target_run.task
    order by pending.created_at, pending.id
    offset 2
  );

  insert into public.ai_question_recommendations (
    couple_id,
    question_id,
    source_run_id,
    reason
  )
  values (
    target_run.couple_id,
    target_question_id,
    target_run.id,
    normalized_rationale
  )
  returning id into recommendation_id;

  completion_result := public.complete_ai_processing_job(
    target_job.id,
    'succeeded',
    null
  );

  if completion_result is not true then
    perform private.raise_app_error('ai_job_completion_failed');
  end if;

  perform private.attach_pending_ai_question_to_waiting_loop(
    target_run.couple_id
  );

  return recommendation_id is not null;
end;
$$;

create or replace function public.succeed_ai_processing_run(
  requested_run_id uuid,
  requested_output jsonb,
  requested_input_token_count integer,
  requested_output_token_count integer,
  requested_latency_ms integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_task text;
begin
  select air.task
  into target_task
  from public.ai_runs as air
  where air.id = requested_run_id;

  if target_task in (
    'generate_general_question',
    'generate_personalized_question'
  ) then
    return private.succeed_ai_generated_question_run(
      requested_run_id,
      requested_output,
      requested_input_token_count,
      requested_output_token_count,
      requested_latency_ms
    );
  end if;

  return public.succeed_ai_processing_run_without_generated_questions_v7(
    requested_run_id,
    requested_output,
    requested_input_token_count,
    requested_output_token_count,
    requested_latency_ms
  );
end;
$$;

revoke execute on function private.succeed_ai_generated_question_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated;
revoke execute on function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated;
grant execute on function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) to service_role;

create or replace function private.enqueue_ai_learning_jobs_after_focused_question()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_curriculum_version integer;
  foundation_question_count integer;
  completed_foundation_count integer;
  next_question_job_type text;
begin
  if old.status = 'completed' or new.status <> 'completed' then
    return new;
  end if;

  if not private.have_all_couple_members_granted_ai_consent(new.couple_id) then
    return new;
  end if;

  select aiqc.version, aiqc.question_count
  into active_curriculum_version, foundation_question_count
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if active_curriculum_version is null then
    return new;
  end if;

  select count(*)::integer
  into completed_foundation_count
  from private.completed_ai_foundation_question_ids(
    new.couple_id,
    active_curriculum_version
  );

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  where aiqr.couple_id = new.couple_id
    and aiqr.question_id = new.question_id
    and aiqr.status = 'pending';

  perform private.enqueue_ai_processing_job_source(
    new.couple_id,
    null,
    new.id,
    'extract_memories',
    'focused:extract_memories:' || new.id::text
  );

  if completed_foundation_count < foundation_question_count then
    perform private.enqueue_ai_processing_job_source(
      new.couple_id,
      null,
      new.id,
      'select_curated_question',
      'focused:select_curated_question:' || new.id::text
    );
  end if;

  if completed_foundation_count
    >= greatest(foundation_question_count - 2, 0)
  then
    next_question_job_type := case
      when completed_foundation_count >= foundation_question_count
        and private.is_ai_personalization_enabled(new.couple_id)
        then 'generate_personalized_question'
      else 'generate_general_question'
    end;

    perform private.enqueue_ai_processing_job_source(
      new.couple_id,
      null,
      new.id,
      next_question_job_type,
      'pool:' || next_question_job_type || ':focused:' || new.id::text
    );
  end if;

  return new;
end;
$$;

create or replace function private.enqueue_ai_learning_jobs_after_completed_question()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_curriculum_version integer;
  foundation_question_count integer;
  completed_foundation_count integer;
  next_question_job_type text;
begin
  if old.status = 'completed' or new.status <> 'completed' then
    return new;
  end if;

  if not private.have_all_couple_members_granted_ai_consent(new.couple_id) then
    return new;
  end if;

  select aiqc.version, aiqc.question_count
  into active_curriculum_version, foundation_question_count
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if active_curriculum_version is null then
    return new;
  end if;

  select count(*)::integer
  into completed_foundation_count
  from private.completed_ai_foundation_question_ids(
    new.couple_id,
    active_curriculum_version
  );

  perform private.enqueue_ai_processing_job(
    new.couple_id,
    new.id,
    'extract_memories',
    'extract_memories:' || new.id::text
  );

  perform private.enqueue_ai_processing_job(
    new.couple_id,
    new.id,
    'generate_feedback',
    'generate_feedback:' || new.id::text
  );

  if completed_foundation_count < foundation_question_count then
    perform private.enqueue_ai_processing_job(
      new.couple_id,
      new.id,
      'select_curated_question',
      'select_curated_question:' || new.id::text
    );
  end if;

  if completed_foundation_count
    >= greatest(foundation_question_count - 2, 0)
  then
    next_question_job_type := case
      when completed_foundation_count >= foundation_question_count
        and private.is_ai_personalization_enabled(new.couple_id)
        then 'generate_personalized_question'
      else 'generate_general_question'
    end;

    perform private.enqueue_ai_processing_job(
      new.couple_id,
      new.id,
      next_question_job_type,
      'pool:' || next_question_job_type || ':daily:' || new.id::text
    );
  end if;

  return new;
end;
$$;

alter function public.claim_ai_processing_jobs(text, integer)
  rename to claim_ai_processing_jobs_with_retry_scan_v7;

revoke execute on function public.claim_ai_processing_jobs_with_retry_scan_v7(
  text,
  integer
) from public, anon, authenticated, service_role;

create or replace function public.claim_ai_processing_jobs(
  requested_worker text,
  requested_limit integer
)
returns table (
  job_id uuid,
  job_couple_id uuid,
  job_daily_question_id uuid,
  job_type text,
  job_attempt integer,
  job_lease_expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  waiting_loop record;
begin
  for waiting_loop in
    select dsl.couple_id, dsl.id
    from public.daily_story_loops as dsl
    where dsl.status = 'question_preparing'
      and not exists (
        select 1
        from public.daily_questions as dq
        where dq.story_loop_id = dsl.id
      )
    order by dsl.couple_date, dsl.created_at, dsl.id
  loop
    perform private.ensure_ai_question_job_for_story_loop(
      waiting_loop.couple_id,
      waiting_loop.id
    );
  end loop;

  return query
    select *
    from public.claim_ai_processing_jobs_with_retry_scan_v7(
      requested_worker,
      requested_limit
    );
end;
$$;

revoke execute on function public.claim_ai_processing_jobs(text, integer)
  from public, anon, authenticated;
grant execute on function public.claim_ai_processing_jobs(text, integer)
  to service_role;

alter function private.try_activate_ai_personalization(uuid)
  rename to try_activate_ai_personalization_without_question_refresh_v8;

create or replace function private.try_activate_ai_personalization(
  target_couple_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  activated boolean;
  active_curriculum_version integer;
  latest_source_type text;
  latest_question_id uuid;
begin
  activated := private.try_activate_ai_personalization_without_question_refresh_v8(
    target_couple_id
  );

  if not activated
    or not private.is_ai_personalization_enabled(target_couple_id)
  then
    return activated;
  end if;

  select aiqc.version
  into active_curriculum_version
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  update public.ai_processing_jobs as aipj
  set
    status = 'cancelled',
    completed_at = now(),
    last_error = 'ai_personalization_activated'
  where aipj.couple_id = target_couple_id
    and aipj.job_type = 'generate_general_question'
    and aipj.status = 'pending';

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  from public.ai_runs as air
  where aiqr.couple_id = target_couple_id
    and aiqr.status = 'pending'
    and air.id = aiqr.source_run_id
    and air.task = 'generate_general_question';

  update public.questions as q
  set is_active = false
  where q.personalized_for_couple_id = target_couple_id
    and q.generated_by_run_id in (
      select air.id
      from public.ai_runs as air
      where air.couple_id = target_couple_id
        and air.task = 'generate_general_question'
    )
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.question_id = q.id
    )
    and not exists (
      select 1
      from public.ai_question_recommendations as aiqr
      where aiqr.question_id = q.id
        and aiqr.status = 'pending'
    );

  select completed.source_type, completed.instance_id
  into latest_source_type, latest_question_id
  from (
    select
      'daily'::text as source_type,
      dq.id as instance_id,
      greatest(dq.updated_at, dq.created_at) as completed_at
    from public.daily_questions as dq
    where dq.couple_id = target_couple_id
      and dq.status = 'completed'

    union all

    select
      'focused'::text,
      aifq.id,
      greatest(aifq.updated_at, aifq.created_at)
    from public.ai_focused_questions as aifq
    where aifq.couple_id = target_couple_id
      and aifq.status = 'completed'
  ) as completed
  order by completed.completed_at desc, completed.instance_id desc
  limit 1;

  if latest_question_id is not null then
    perform private.enqueue_ai_processing_job_source(
      target_couple_id,
      case when latest_source_type = 'daily' then latest_question_id end,
      case when latest_source_type = 'focused' then latest_question_id end,
      'generate_personalized_question',
      'personalization:' || active_curriculum_version::text
        || ':activated:' || latest_source_type
        || ':' || latest_question_id::text
    );
  end if;

  return true;
end;
$$;

revoke execute on function private.try_activate_ai_personalization(uuid)
  from public, anon, authenticated;
revoke execute on function private.try_activate_ai_personalization_without_question_refresh_v8(
  uuid
) from public, anon, authenticated;
