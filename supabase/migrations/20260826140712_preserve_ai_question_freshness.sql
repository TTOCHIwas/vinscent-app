alter table public.ai_processing_jobs
  add column context_captured_at timestamptz;

comment on column public.ai_processing_jobs.context_captured_at is
  'Latest instant at which the generation worker loaded its question context.';

create index if not exists daily_questions_couple_created_idx
  on public.daily_questions (couple_id, created_at desc, id);

create index if not exists ai_focused_questions_couple_created_idx
  on public.ai_focused_questions (couple_id, created_at desc, id);

create or replace function private.get_recent_exposed_ai_question_texts(
  target_couple_id uuid,
  excluded_daily_question_id uuid default null,
  excluded_focused_question_id uuid default null,
  requested_limit integer default 30
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      recent.question_text
      order by recent.exposed_at desc, recent.instance_id
    ),
    '[]'::jsonb
  )
  from (
    select exposures.*
    from (
      select
        dq.id as instance_id,
        dq.created_at as exposed_at,
        q.question_text
      from public.daily_questions as dq
      join public.questions as q on q.id = dq.question_id
      where dq.couple_id = target_couple_id
        and dq.id is distinct from excluded_daily_question_id

      union all

      select
        aifq.id,
        aifq.created_at,
        q.question_text
      from public.ai_focused_questions as aifq
      join public.questions as q on q.id = aifq.question_id
      where aifq.couple_id = target_couple_id
        and aifq.id is distinct from excluded_focused_question_id
    ) as exposures
    order by exposures.exposed_at desc, exposures.instance_id
    limit least(greatest(requested_limit, 1), 50)
  ) as recent;
$$;

create or replace function private.get_pending_ai_question_texts(
  target_couple_id uuid,
  requested_limit integer default 10
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      pending.question_text
      order by pending.created_at, pending.recommendation_id
    ),
    '[]'::jsonb
  )
  from (
    select
      aiqr.id as recommendation_id,
      aiqr.created_at,
      q.question_text
    from public.ai_question_recommendations as aiqr
    join public.questions as q on q.id = aiqr.question_id
    where aiqr.couple_id = target_couple_id
      and aiqr.status = 'pending'
      and aiqr.expires_at > now()
      and q.is_active
    order by aiqr.created_at, aiqr.id
    limit least(greatest(requested_limit, 1), 20)
  ) as pending;
$$;

create or replace function public.get_ai_processing_job_context(
  requested_job_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_job public.ai_processing_jobs%rowtype;
  base_context jsonb;
  captured_at timestamptz := statement_timestamp();
begin
  if requested_job_id is null then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = requested_job_id;

  if not found
    or target_job.job_type = 'generate_general_question'
  then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  base_context := public.get_ai_processing_job_context_with_answers_v5(
    requested_job_id
  );

  update public.ai_processing_jobs as aipj
  set context_captured_at = captured_at
  where aipj.id = target_job.id;

  return base_context || jsonb_build_object(
    'recent_exposed_questions',
    private.get_recent_exposed_ai_question_texts(
      target_job.couple_id,
      target_job.daily_question_id,
      target_job.focused_question_id,
      30
    ),
    'pending_question_candidates',
    private.get_pending_ai_question_texts(target_job.couple_id, 10)
  );
end;
$$;

alter function public.get_ai_general_question_job_context(uuid)
  rename to get_ai_general_question_job_context_without_freshness_v2;

revoke execute on function
  public.get_ai_general_question_job_context_without_freshness_v2(uuid)
  from public, anon, authenticated, service_role;

create or replace function public.get_ai_general_question_job_context(
  requested_job_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  result := public.get_ai_general_question_job_context_without_freshness_v2(
    requested_job_id
  );

  update public.ai_processing_jobs as aipj
  set context_captured_at = statement_timestamp()
  where aipj.id = requested_job_id;

  return result;
end;
$$;

create or replace function private.enforce_ai_question_queue_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  pending_count integer;
  approved_follow_up_count integer;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_question_recommendation'),
    hashtext(new.couple_id::text)
  );

  update public.ai_question_recommendations
  set status = 'expired'
  where couple_id = new.couple_id
    and status = 'pending'
    and expires_at <= now();

  select
    count(*)::integer,
    count(*) filter (
      where source_follow_up_id is not null
    )::integer
  into pending_count, approved_follow_up_count
  from public.ai_question_recommendations
  where couple_id = new.couple_id
    and status = 'pending';

  if new.source_follow_up_id is not null
    and approved_follow_up_count >= 2
  then
    perform private.raise_app_error('ai_follow_up_queue_full');
  end if;

  if new.source_run_id is not null then
    update public.ai_question_recommendations
    set status = 'expired'
    where couple_id = new.couple_id
      and status = 'pending'
      and source_run_id is not null;
  elsif pending_count >= 2 then
    update public.ai_question_recommendations
    set status = 'expired'
    where couple_id = new.couple_id
      and status = 'pending'
      and source_run_id is not null;
  end if;

  select count(*)::integer
  into pending_count
  from public.ai_question_recommendations
  where couple_id = new.couple_id
    and status = 'pending';

  if pending_count >= 2 then
    if new.source_follow_up_id is not null then
      perform private.raise_app_error('ai_follow_up_queue_full');
    end if;
    new.status := 'expired';
  end if;

  update public.questions as q
  set is_active = false
  where q.id in (
    select aiqr.question_id
    from public.ai_question_recommendations as aiqr
    where aiqr.couple_id = new.couple_id
      and aiqr.status = 'expired'
      and not exists (
        select 1
        from public.daily_questions as dq
        where dq.question_id = aiqr.question_id
      )
  );

  if new.status = 'expired' then
    update public.questions
    set is_active = false
    where id = new.question_id
      and not exists (
        select 1
        from public.daily_questions as dq
        where dq.question_id = new.question_id
      );
  end if;

  return new;
end;
$$;

create or replace function private.assign_pending_ai_question_to_story_loop(
  target_couple public.couples,
  target_story_loop public.daily_story_loops
)
returns public.daily_questions
language plpgsql
security definer
set search_path = ''
as $$
declare
  expected_job_type text;
  selected_recommendation_id uuid;
  selected_question_id uuid;
  target_daily_question public.daily_questions%rowtype;
begin
  expected_job_type := private.ai_generated_question_job_type(
    target_couple.id
  );

  perform pg_advisory_xact_lock(
    hashtext('ai_question_recommendation'),
    hashtext(target_couple.id::text)
  );

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  from public.ai_runs as air
  left join public.ai_processing_jobs as source_job
    on source_job.id = air.job_id,
    public.questions as q
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and air.id = aiqr.source_run_id
    and q.id = aiqr.question_id
    and (
      aiqr.expires_at <= now()
      or expected_job_type is null
      or air.task <> expected_job_type
      or q.source <> 'ai'
      or q.personalized_for_couple_id <> target_couple.id
      or not q.is_active
      or source_job.id is null
      or source_job.context_captured_at is null
      or exists (
        select 1
        from public.daily_questions as newer_dq
        where newer_dq.couple_id = target_couple.id
          and newer_dq.id is distinct from source_job.daily_question_id
          and newer_dq.created_at > source_job.context_captured_at
      )
      or exists (
        select 1
        from public.ai_focused_questions as newer_aifq
        where newer_aifq.couple_id = target_couple.id
          and newer_aifq.id is distinct from source_job.focused_question_id
          and newer_aifq.created_at > source_job.context_captured_at
      )
      or exists (
        select 1
        from public.daily_questions as used_dq
        where used_dq.couple_id = target_couple.id
          and used_dq.question_id = q.id
      )
    );

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  from public.ai_user_question_follow_ups as aiuqfu,
    public.questions as q
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and aiuqfu.id = aiqr.source_follow_up_id
    and q.id = aiqr.question_id
    and (
      aiqr.expires_at <= now()
      or aiuqfu.status <> 'approved'
      or aiuqfu.shared_question_id <> q.id
      or q.source <> 'ai'
      or q.personalized_for_couple_id <> target_couple.id
      or not q.is_active
      or exists (
        select 1
        from public.daily_questions as used_dq
        where used_dq.couple_id = target_couple.id
          and used_dq.question_id = q.id
      )
    );

  update public.questions as q
  set is_active = false
  where q.id in (
    select aiqr.question_id
    from public.ai_question_recommendations as aiqr
    where aiqr.couple_id = target_couple.id
      and aiqr.status = 'expired'
      and not exists (
        select 1
        from public.daily_questions as dq
        where dq.question_id = aiqr.question_id
      )
  );

  select aiqr.id, aiqr.question_id
  into selected_recommendation_id, selected_question_id
  from public.ai_question_recommendations as aiqr
  join public.questions as q on q.id = aiqr.question_id
  left join public.ai_runs as air on air.id = aiqr.source_run_id
  left join public.ai_processing_jobs as source_job
    on source_job.id = air.job_id
  left join public.ai_user_question_follow_ups as aiuqfu
    on aiuqfu.id = aiqr.source_follow_up_id
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and aiqr.expires_at > now()
    and q.source = 'ai'
    and q.personalized_for_couple_id = target_couple.id
    and q.is_active
    and (
      (
        aiqr.source_follow_up_id is not null
        and aiuqfu.status = 'approved'
        and aiuqfu.shared_question_id = q.id
      )
      or (
        aiqr.source_run_id is not null
        and expected_job_type is not null
        and air.task = expected_job_type
        and source_job.context_captured_at is not null
        and not exists (
          select 1
          from public.daily_questions as newer_dq
          where newer_dq.couple_id = target_couple.id
            and newer_dq.id is distinct from source_job.daily_question_id
            and newer_dq.created_at > source_job.context_captured_at
        )
        and not exists (
          select 1
          from public.ai_focused_questions as newer_aifq
          where newer_aifq.couple_id = target_couple.id
            and newer_aifq.id is distinct from source_job.focused_question_id
            and newer_aifq.created_at > source_job.context_captured_at
        )
      )
    )
    and not exists (
      select 1
      from public.daily_questions as used_dq
      where used_dq.couple_id = target_couple.id
        and used_dq.question_id = q.id
    )
  order by
    case when aiqr.source_follow_up_id is not null then 0 else 1 end,
    aiqr.created_at,
    aiqr.id
  limit 1
  for update of aiqr;

  if selected_question_id is null then
    return null;
  end if;

  insert into public.daily_questions (
    couple_id,
    question_id,
    assigned_date,
    story_loop_id
  )
  values (
    target_couple.id,
    selected_question_id,
    target_story_loop.couple_date,
    target_story_loop.id
  )
  on conflict on constraint daily_questions_couple_date_unique do nothing;

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id
    and dq.assigned_date = target_story_loop.couple_date
  for update;

  if not found
    or target_daily_question.story_loop_id <> target_story_loop.id
    or target_daily_question.question_id <> selected_question_id
  then
    perform private.raise_app_error('question_assignment_failed');
  end if;

  update public.ai_question_recommendations as aiqr
  set
    status = 'used',
    assigned_daily_question_id = target_daily_question.id,
    used_at = now()
  where aiqr.id = selected_recommendation_id
    and aiqr.status = 'pending';

  return target_daily_question;
end;
$$;

update public.ai_question_recommendations
set status = 'expired'
where status = 'pending'
  and source_run_id is not null;

update public.questions as q
set is_active = false
where q.id in (
  select aiqr.question_id
  from public.ai_question_recommendations as aiqr
  where aiqr.status = 'expired'
    and aiqr.source_run_id is not null
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.question_id = aiqr.question_id
    )
);

revoke execute on function
  private.get_recent_exposed_ai_question_texts(uuid, uuid, uuid, integer)
  from public, anon, authenticated;
revoke execute on function
  private.get_pending_ai_question_texts(uuid, integer)
  from public, anon, authenticated;
revoke execute on function
  private.enforce_ai_question_queue_capacity()
  from public, anon, authenticated;
revoke execute on function
  private.assign_pending_ai_question_to_story_loop(
    public.couples,
    public.daily_story_loops
  )
  from public, anon, authenticated;
revoke execute on function public.get_ai_processing_job_context(uuid)
  from public, anon, authenticated;
revoke execute on function public.get_ai_general_question_job_context(uuid)
  from public, anon, authenticated;

grant execute on function public.get_ai_processing_job_context(uuid)
  to service_role;
grant execute on function public.get_ai_general_question_job_context(uuid)
  to service_role;
