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

create or replace function private.enqueue_ai_processing_job(
  requested_couple_id uuid,
  requested_daily_question_id uuid,
  requested_job_type text,
  requested_deduplication_key text,
  requested_available_at timestamptz default now()
)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select private.enqueue_ai_processing_job_source(
    requested_couple_id,
    requested_daily_question_id,
    null,
    requested_job_type,
    requested_deduplication_key,
    requested_available_at
  );
$$;

revoke execute on function private.enqueue_ai_processing_job_source(
  uuid,
  uuid,
  uuid,
  text,
  text,
  timestamptz
) from public, anon, authenticated;
revoke execute on function private.enqueue_ai_processing_job(
  uuid,
  uuid,
  text,
  text,
  timestamptz
) from public, anon, authenticated;

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

  next_question_job_type := case
    when completed_foundation_count < foundation_question_count
      then 'select_curated_question'
    else 'generate_personalized_question'
  end;

  perform private.enqueue_ai_processing_job_source(
    new.couple_id,
    null,
    new.id,
    next_question_job_type,
    'focused:' || next_question_job_type || ':' || new.id::text
  );

  return new;
end;
$$;

create trigger ai_focused_questions_enqueue_ai_learning_jobs
  after update of status on public.ai_focused_questions
  for each row
  when (old.status is distinct from new.status)
  execute function private.enqueue_ai_learning_jobs_after_focused_question();

revoke execute on function private.enqueue_ai_learning_jobs_after_focused_question()
  from public, anon, authenticated;

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

  next_question_job_type := case
    when completed_foundation_count < foundation_question_count
      then 'select_curated_question'
    else 'generate_personalized_question'
  end;

  perform private.enqueue_ai_processing_job(
    new.couple_id,
    new.id,
    next_question_job_type,
    next_question_job_type || ':' || new.id::text
  );

  return new;
end;
$$;

revoke execute on function private.enqueue_ai_learning_jobs_after_completed_question()
  from public, anon, authenticated;

create or replace function private.assign_question_to_story_loop(
  target_couple public.couples,
  target_story_loop public.daily_story_loops
)
returns public.daily_questions
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_daily_question public.daily_questions%rowtype;
  selected_question_id uuid;
  selected_recommendation_id uuid;
begin
  select *
  into target_daily_question
  from public.daily_questions as dq
  where dq.story_loop_id = target_story_loop.id
  for update;

  if found then
    return target_daily_question;
  end if;

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and (
      aiqr.expires_at <= now()
      or private.is_ai_foundation_question_completed(
        target_couple.id,
        aiqr.question_id
      )
      or exists (
        select 1
        from public.daily_questions as used_dq
        where used_dq.couple_id = target_couple.id
          and used_dq.question_id = aiqr.question_id
      )
      or not exists (
        select 1
        from public.questions as invalid_q
        where invalid_q.id = aiqr.question_id
          and invalid_q.is_active = true
          and (
            invalid_q.source = 'curated'
            or (
              invalid_q.source = 'ai'
              and invalid_q.personalized_for_couple_id = target_couple.id
            )
          )
      )
    );

  select aiqr.id, aiqr.question_id
  into selected_recommendation_id, selected_question_id
  from public.ai_question_recommendations as aiqr
  join public.questions as q on q.id = aiqr.question_id
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and aiqr.expires_at > now()
    and q.is_active = true
    and (
      q.source = 'curated'
      or (
        q.source = 'ai'
        and q.personalized_for_couple_id = target_couple.id
      )
    )
    and not private.is_ai_foundation_question_completed(
      target_couple.id,
      q.id
    )
    and not exists (
      select 1
      from public.daily_questions as used_dq
      where used_dq.couple_id = target_couple.id
        and used_dq.question_id = q.id
    )
  order by aiqr.created_at desc, aiqr.id
  limit 1
  for update of aiqr;

  if selected_question_id is null then
    select q.id
    into selected_question_id
    from public.questions as q
    join public.ai_question_curricula as aiqc
      on aiqc.version = q.curriculum_version
    where q.source = 'curated'
      and q.is_active = true
      and aiqc.status = 'active'
      and not private.is_ai_foundation_question_completed(
        target_couple.id,
        q.id
      )
      and not exists (
        select 1
        from public.daily_questions as used_dq
        where used_dq.couple_id = target_couple.id
          and used_dq.question_id = q.id
      )
    order by q.curriculum_position, q.id
    limit 1;
  end if;

  if selected_question_id is null then
    select q.id
    into selected_question_id
    from public.questions as q
    left join lateral (
      select max(used_dq.assigned_date) as last_assigned_date
      from public.daily_questions as used_dq
      where used_dq.couple_id = target_couple.id
        and used_dq.question_id = q.id
    ) as usage on true
    where q.source = 'curated'
      and q.is_active = true
    order by
      usage.last_assigned_date nulls first,
      q.curriculum_version desc nulls last,
      q.curriculum_position nulls last,
      q.created_at,
      q.id
    limit 1;
  end if;

  if selected_question_id is null then
    perform private.raise_app_error('question_pool_empty');
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

  select *
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id
    and dq.assigned_date = target_story_loop.couple_date
  for update;

  if not found or target_daily_question.story_loop_id <> target_story_loop.id then
    perform private.raise_app_error('question_assignment_failed');
  end if;

  perform private.promote_ai_focused_question_to_daily(
    target_daily_question.id
  );

  select *
  into target_daily_question
  from public.daily_questions as dq
  where dq.id = target_daily_question.id;

  if selected_recommendation_id is not null
    and target_daily_question.question_id = selected_question_id
  then
    update public.ai_question_recommendations as aiqr
    set
      status = 'used',
      assigned_daily_question_id = target_daily_question.id,
      used_at = now()
    where aiqr.id = selected_recommendation_id
      and aiqr.status = 'pending';
  end if;

  return target_daily_question;
end;
$$;

revoke execute on function private.assign_question_to_story_loop(
  public.couples,
  public.daily_story_loops
) from public, anon, authenticated;

create or replace function private.preserve_promoted_story_loop_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  assigned_question_status text;
begin
  if new.status <> 'question_generated' then
    return new;
  end if;

  select dq.status
  into assigned_question_status
  from public.daily_questions as dq
  where dq.story_loop_id = new.id;

  if assigned_question_status in ('answered_by_one', 'completed') then
    new.status := assigned_question_status;
  end if;

  return new;
end;
$$;

create trigger daily_story_loops_preserve_promoted_question_status
  before update of status on public.daily_story_loops
  for each row
  execute function private.preserve_promoted_story_loop_status();

revoke execute on function private.preserve_promoted_story_loop_status()
  from public, anon, authenticated;

create or replace function private.is_ai_memory_review_eligible(
  target_memory_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.ai_memories as aim
    where aim.id = target_memory_id
      and (
        exists (
          select 1
          from public.ai_memory_evidence as aime
          where aime.memory_id = aim.id
        )
        or exists (
          select 1
          from public.ai_focused_memory_evidence as aifme
          where aifme.memory_id = aim.id
        )
      )
      and (
        aim.evidence_type = 'explicit'
        or (
          aim.evidence_type = 'repeated_pattern'
          and (
            select count(distinct evidence.question_instance_id)
            from (
              select dqa.daily_question_id as question_instance_id
              from public.ai_memory_evidence as aime
              join public.daily_question_answers as dqa
                on dqa.id = aime.answer_id
              where aime.memory_id = aim.id

              union

              select aifqa.focused_question_id
              from public.ai_focused_memory_evidence as aifme
              join public.ai_focused_question_answers as aifqa
                on aifqa.id = aifme.answer_id
              where aifme.memory_id = aim.id
            ) as evidence
          ) >= 2
        )
      )
  );
$$;

create or replace function private.is_ai_foundation_processing_complete(
  target_couple_id uuid,
  target_curriculum_version integer
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.couple_id = target_couple_id
      and dq.status = 'completed'
      and q.curriculum_version = target_curriculum_version
      and not exists (
        select 1
        from public.ai_processing_jobs as aipj
        where aipj.couple_id = target_couple_id
          and aipj.daily_question_id = dq.id
          and aipj.focused_question_id is null
          and aipj.job_type = 'extract_memories'
          and aipj.status = 'succeeded'
      )

    union all

    select 1
    from public.ai_focused_questions as aifq
    join public.questions as q on q.id = aifq.question_id
    where aifq.couple_id = target_couple_id
      and aifq.status = 'completed'
      and q.curriculum_version = target_curriculum_version
      and not exists (
        select 1
        from public.ai_processing_jobs as aipj
        where aipj.couple_id = target_couple_id
          and aipj.focused_question_id = aifq.id
          and aipj.daily_question_id is null
          and aipj.job_type = 'extract_memories'
          and aipj.status = 'succeeded'
      )
  );
$$;

create or replace function private.try_activate_ai_personalization(
  target_couple_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_curriculum public.ai_question_curricula%rowtype;
  completed_foundation_count integer;
begin
  if target_couple_id is null
    or not private.have_all_couple_members_granted_ai_consent(target_couple_id)
  then
    return false;
  end if;

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if not found then
    return false;
  end if;

  if exists (
    select 1
    from public.ai_personalization_states as aips
    where aips.couple_id = target_couple_id
      and aips.curriculum_version = active_curriculum.version
  ) then
    return true;
  end if;

  select count(*)::integer
  into completed_foundation_count
  from private.completed_ai_foundation_question_ids(
    target_couple_id,
    active_curriculum.version
  );

  if completed_foundation_count < active_curriculum.question_count
    or not private.is_ai_foundation_processing_complete(
      target_couple_id,
      active_curriculum.version
    )
    or exists (
      select 1
      from public.ai_memories as aim
      where aim.couple_id = target_couple_id
        and aim.origin_curriculum_version = active_curriculum.version
        and aim.state = 'pending'
        and private.is_ai_memory_review_eligible(aim.id)
    )
  then
    return false;
  end if;

  insert into public.ai_personalization_states (
    couple_id,
    curriculum_version,
    activated_at
  )
  values (
    target_couple_id,
    active_curriculum.version,
    now()
  )
  on conflict (couple_id, curriculum_version) do nothing;

  return true;
end;
$$;

revoke execute on function private.is_ai_memory_review_eligible(uuid)
  from public, anon, authenticated;
revoke execute on function private.is_ai_foundation_processing_complete(uuid, integer)
  from public, anon, authenticated;
revoke execute on function private.try_activate_ai_personalization(uuid)
  from public, anon, authenticated;

create or replace function public.get_ai_learning_progress()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  completed_count integer;
  learning_stage text;
  domain_progress jsonb;
  my_consent_status text;
  partner_consent_status text;
  partner_user_id uuid;
  all_members_consented boolean;
  foundation_complete boolean;
  memory_processing_complete boolean;
  memory_processing_failed boolean;
  personalization_enabled boolean;
  my_pending_review_count integer;
  partner_pending_review_count integer;
  personalization_status text;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

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
  into completed_count
  from private.completed_ai_foundation_question_ids(
    active_couple.id,
    active_curriculum.version
  );

  learning_stage := case
    when completed_count < ceil(active_curriculum.question_count / 3.0)
      then 'collecting'
    when completed_count < ceil(active_curriculum.question_count * 2 / 3.0)
      then 'exploring'
    when completed_count < active_curriculum.question_count
      then 'refining'
    else 'ready'
  end;

  select coalesce(
    jsonb_object_agg(
      domain_rows.learning_domain,
      jsonb_build_object(
        'completed_count', domain_rows.completed_count,
        'total_count', domain_rows.total_count
      )
      order by domain_rows.learning_domain
    ),
    '{}'::jsonb
  )
  into domain_progress
  from (
    select
      q.learning_domain,
      count(*)::integer as total_count,
      count(*) filter (
        where private.is_ai_foundation_question_completed(
          active_couple.id,
          q.id
        )
      )::integer as completed_count
    from public.questions as q
    where q.curriculum_version = active_curriculum.version
      and q.is_active = true
    group by q.learning_domain
  ) as domain_rows;

  partner_user_id := case
    when active_couple.user_a_id = current_user_id
      then active_couple.user_b_id
    else active_couple.user_a_id
  end;

  select coalesce(auc.status, 'revoked')
  into my_consent_status
  from (select 1) as singleton
  left join public.ai_user_consents as auc
    on auc.couple_id = active_couple.id
    and auc.user_id = current_user_id;

  select coalesce(auc.status, 'revoked')
  into partner_consent_status
  from (select 1) as singleton
  left join public.ai_user_consents as auc
    on auc.couple_id = active_couple.id
    and auc.user_id = partner_user_id;

  all_members_consented := private.have_all_couple_members_granted_ai_consent(
    active_couple.id
  );
  foundation_complete := completed_count >= active_curriculum.question_count;
  memory_processing_complete := foundation_complete
    and private.is_ai_foundation_processing_complete(
      active_couple.id,
      active_curriculum.version
    );

  select foundation_complete and exists (
    select 1
    from (
      select
        'daily'::text as source_type,
        dq.id as source_id
      from public.daily_questions as dq
      join public.questions as q on q.id = dq.question_id
      where dq.couple_id = active_couple.id
        and dq.status = 'completed'
        and q.curriculum_version = active_curriculum.version

      union all

      select
        'focused'::text,
        aifq.id
      from public.ai_focused_questions as aifq
      join public.questions as q on q.id = aifq.question_id
      where aifq.couple_id = active_couple.id
        and aifq.status = 'completed'
        and q.curriculum_version = active_curriculum.version
    ) as completed_question
    where not exists (
      select 1
      from public.ai_processing_jobs as succeeded_job
      where succeeded_job.couple_id = active_couple.id
        and succeeded_job.job_type = 'extract_memories'
        and succeeded_job.status = 'succeeded'
        and (
          (
            completed_question.source_type = 'daily'
            and succeeded_job.daily_question_id = completed_question.source_id
          )
          or (
            completed_question.source_type = 'focused'
            and succeeded_job.focused_question_id = completed_question.source_id
          )
        )
    )
    and exists (
      select 1
      from public.ai_processing_jobs as failed_job
      where failed_job.couple_id = active_couple.id
        and failed_job.job_type = 'extract_memories'
        and failed_job.status in ('failed', 'cancelled')
        and (
          (
            completed_question.source_type = 'daily'
            and failed_job.daily_question_id = completed_question.source_id
          )
          or (
            completed_question.source_type = 'focused'
            and failed_job.focused_question_id = completed_question.source_id
          )
        )
    )
    and not exists (
      select 1
      from public.ai_processing_jobs as running_job
      where running_job.couple_id = active_couple.id
        and running_job.job_type = 'extract_memories'
        and running_job.status in ('pending', 'processing')
        and (
          (
            completed_question.source_type = 'daily'
            and running_job.daily_question_id = completed_question.source_id
          )
          or (
            completed_question.source_type = 'focused'
            and running_job.focused_question_id = completed_question.source_id
          )
        )
    )
  )
  into memory_processing_failed;

  if memory_processing_complete and all_members_consented then
    perform private.try_activate_ai_personalization(active_couple.id);
  end if;

  personalization_enabled := private.is_ai_personalization_enabled(
    active_couple.id
  );

  select count(*)::integer
  into my_pending_review_count
  from public.ai_memories as aim
  where aim.couple_id = active_couple.id
    and aim.origin_curriculum_version = active_curriculum.version
    and aim.state = 'pending'
    and private.is_ai_memory_review_eligible(aim.id)
    and (
      (aim.scope = 'personal' and aim.subject_user_id = current_user_id)
      or (
        aim.scope = 'couple'
        and not exists (
          select 1
          from public.ai_memory_confirmations as aimc
          where aimc.memory_id = aim.id
            and aimc.user_id = current_user_id
        )
      )
    );

  select count(*)::integer
  into partner_pending_review_count
  from public.ai_memories as aim
  where aim.couple_id = active_couple.id
    and aim.origin_curriculum_version = active_curriculum.version
    and aim.state = 'pending'
    and private.is_ai_memory_review_eligible(aim.id)
    and (
      (aim.scope = 'personal' and aim.subject_user_id = partner_user_id)
      or (
        aim.scope = 'couple'
        and not exists (
          select 1
          from public.ai_memory_confirmations as aimc
          where aimc.memory_id = aim.id
            and aimc.user_id = partner_user_id
        )
      )
    );

  personalization_status := case
    when not foundation_complete then 'collecting'
    when not memory_processing_complete and memory_processing_failed
      then 'processing_error'
    when not memory_processing_complete then 'processing'
    when personalization_enabled then 'ready'
    when my_pending_review_count > 0 then 'reviewing'
    when partner_pending_review_count > 0 then 'waiting_partner'
    else 'processing'
  end;

  return jsonb_build_object(
    'curriculum_version', active_curriculum.version,
    'completed_count', completed_count,
    'total_count', active_curriculum.question_count,
    'stage', learning_stage,
    'domain_progress', domain_progress,
    'my_consent_status', my_consent_status,
    'partner_consent_status', partner_consent_status,
    'ai_enabled', all_members_consented,
    'foundation_complete', foundation_complete,
    'memory_processing_complete', memory_processing_complete,
    'personalization_status', personalization_status,
    'personalization_enabled', personalization_enabled,
    'my_pending_review_count', my_pending_review_count,
    'partner_pending_review_count', partner_pending_review_count
  );
end;
$$;

create or replace function public.list_ai_memories()
returns table (
  memory_id uuid,
  memory_scope text,
  subject_user_id uuid,
  memory_kind text,
  memory_statement text,
  memory_confidence numeric,
  memory_state text,
  evidence_answer_ids uuid[],
  memory_created_at timestamptz,
  memory_updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  completed_count integer;
  all_members_consented boolean;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  all_members_consented := private.have_all_couple_members_granted_ai_consent(
    active_couple.id
  );

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  select count(*)::integer
  into completed_count
  from private.completed_ai_foundation_question_ids(
    active_couple.id,
    active_curriculum.version
  );

  if completed_count < active_curriculum.question_count
    or not private.is_ai_foundation_processing_complete(
      active_couple.id,
      active_curriculum.version
    )
  then
    return;
  end if;

  return query
    select
      aim.id,
      aim.scope,
      aim.subject_user_id,
      aim.kind,
      aim.statement,
      aim.confidence,
      aim.state,
      array(
        select evidence.answer_id
        from (
          select aime.answer_id, aime.created_at
          from public.ai_memory_evidence as aime
          where aime.memory_id = aim.id

          union all

          select aifme.answer_id, aifme.created_at
          from public.ai_focused_memory_evidence as aifme
          where aifme.memory_id = aim.id
        ) as evidence
        order by evidence.created_at, evidence.answer_id
      ),
      aim.created_at,
      aim.updated_at
    from public.ai_memories as aim
    where aim.couple_id = active_couple.id
      and aim.state in ('pending', 'active')
      and private.is_ai_memory_review_eligible(aim.id)
      and (
        (
          aim.scope = 'personal'
          and aim.subject_user_id = current_user_id
        )
        or (
          all_members_consented
          and aim.scope = 'personal'
          and aim.subject_user_id <> current_user_id
          and aim.state = 'active'
        )
        or (
          all_members_consented
          and aim.scope = 'couple'
        )
      )
    order by aim.updated_at desc, aim.id;
end;
$$;

create or replace function public.confirm_ai_memory(
  requested_memory_id uuid,
  requested_decision text
)
returns table (
  memory_id uuid,
  memory_state text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  target_memory public.ai_memories%rowtype;
  normalized_decision text := btrim(requested_decision);
  next_state text;
  confirmed_member_count integer;
  completed_count integer;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_memory_id is null
    or normalized_decision is null
    or normalized_decision not in ('confirmed', 'rejected')
  then
    perform private.raise_app_error('invalid_ai_memory_confirmation');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.have_all_couple_members_granted_ai_consent(active_couple.id) then
    perform private.raise_app_error('ai_consent_required');
  end if;

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  select count(*)::integer
  into completed_count
  from private.completed_ai_foundation_question_ids(
    active_couple.id,
    active_curriculum.version
  );

  if completed_count < active_curriculum.question_count
    or not private.is_ai_foundation_processing_complete(
      active_couple.id,
      active_curriculum.version
    )
  then
    perform private.raise_app_error('ai_memory_review_not_ready');
  end if;

  select aim.*
  into target_memory
  from public.ai_memories as aim
  where aim.id = requested_memory_id
    and aim.couple_id = active_couple.id
    and aim.state = 'pending'
    and private.is_ai_memory_review_eligible(aim.id)
  for update;

  if not found then
    perform private.raise_app_error('ai_memory_not_found');
  end if;

  if target_memory.scope = 'personal'
    and target_memory.subject_user_id <> current_user_id
  then
    perform private.raise_app_error('ai_memory_confirmation_forbidden');
  end if;

  if exists (
    select 1
    from public.ai_memory_confirmations as aimc
    where aimc.memory_id = target_memory.id
      and aimc.user_id = current_user_id
  ) then
    perform private.raise_app_error('ai_memory_already_reviewed');
  end if;

  insert into public.ai_memory_confirmations (
    memory_id,
    user_id,
    decision,
    decided_at
  )
  values (
    target_memory.id,
    current_user_id,
    normalized_decision,
    now()
  );

  if normalized_decision = 'rejected' then
    next_state := 'rejected';
  elsif target_memory.scope = 'personal' then
    next_state := 'active';
  else
    select count(*)::integer
    into confirmed_member_count
    from public.ai_memory_confirmations as aimc
    where aimc.memory_id = target_memory.id
      and aimc.decision = 'confirmed'
      and aimc.user_id in (
        active_couple.user_a_id,
        active_couple.user_b_id
      );

    next_state := case
      when confirmed_member_count = 2 then 'active'
      else 'pending'
    end;
  end if;

  update public.ai_memories as aim
  set state = next_state
  where aim.id = target_memory.id;

  perform private.try_activate_ai_personalization(active_couple.id);

  return query
    select target_memory.id, next_state;
end;
$$;

revoke execute on function public.get_ai_learning_progress()
  from public, anon;
revoke execute on function public.list_ai_memories()
  from public, anon;
revoke execute on function public.confirm_ai_memory(uuid, text)
  from public, anon;

grant execute on function public.get_ai_learning_progress()
  to authenticated;
grant execute on function public.list_ai_memories()
  to authenticated;
grant execute on function public.confirm_ai_memory(uuid, text)
  to authenticated;
