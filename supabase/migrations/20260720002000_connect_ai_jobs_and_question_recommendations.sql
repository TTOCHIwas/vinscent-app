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

  select count(distinct dq.question_id)::integer
  into completed_foundation_count
  from public.daily_questions as dq
  join public.questions as q
    on q.id = dq.question_id
  where dq.couple_id = new.couple_id
    and dq.status = 'completed'
    and q.curriculum_version = active_curriculum_version;

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

create trigger daily_questions_enqueue_ai_learning_jobs
  after update of status on public.daily_questions
  for each row
  when (old.status is distinct from new.status)
  execute function private.enqueue_ai_learning_jobs_after_completed_question();

create or replace function private.enqueue_ai_resume_job_after_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_curriculum_version integer;
  foundation_question_count integer;
  completed_foundation_count integer;
  latest_completed_question_id uuid;
  next_question_job_type text;
  user_a_consent_revision integer;
  user_b_consent_revision integer;
begin
  if new.status <> 'granted'
    or (
      tg_op = 'UPDATE'
      and old.status = 'granted'
      and old.policy_version = new.policy_version
    )
    or not private.have_all_couple_members_granted_ai_consent(new.couple_id)
  then
    return new;
  end if;

  select aiqc.version, aiqc.question_count
  into active_curriculum_version, foundation_question_count
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  select dq.id
  into latest_completed_question_id
  from public.daily_questions as dq
  where dq.couple_id = new.couple_id
    and dq.status = 'completed'
  order by dq.assigned_date desc, dq.created_at desc, dq.id
  limit 1;

  if active_curriculum_version is null
    or latest_completed_question_id is null
  then
    return new;
  end if;

  select count(distinct dq.question_id)::integer
  into completed_foundation_count
  from public.daily_questions as dq
  join public.questions as q
    on q.id = dq.question_id
  where dq.couple_id = new.couple_id
    and dq.status = 'completed'
    and q.curriculum_version = active_curriculum_version;

  next_question_job_type := case
    when completed_foundation_count < foundation_question_count
      then 'select_curated_question'
    else 'generate_personalized_question'
  end;

  select
    max(auc.revision) filter (where auc.user_id = c.user_a_id),
    max(auc.revision) filter (where auc.user_id = c.user_b_id)
  into user_a_consent_revision, user_b_consent_revision
  from public.couples as c
  join public.ai_user_consents as auc
    on auc.couple_id = c.id
  where c.id = new.couple_id
  group by c.id;

  perform private.enqueue_ai_processing_job(
    new.couple_id,
    latest_completed_question_id,
    next_question_job_type,
    next_question_job_type
      || ':consent_resume:'
      || new.couple_id::text
      || ':'
      || latest_completed_question_id::text
      || ':'
      || user_a_consent_revision::text
      || ':'
      || user_b_consent_revision::text
  );

  return new;
end;
$$;

create trigger ai_user_consents_enqueue_resume_job
  after insert or update of status, policy_version
  on public.ai_user_consents
  for each row
  execute function private.enqueue_ai_resume_job_after_consent();

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
  join public.questions as q
    on q.id = aiqr.question_id
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

revoke execute on function private.enqueue_ai_learning_jobs_after_completed_question()
  from public, anon, authenticated;
revoke execute on function private.enqueue_ai_resume_job_after_consent()
  from public, anon, authenticated;
revoke execute on function private.assign_question_to_story_loop(
  public.couples,
  public.daily_story_loops
) from public, anon, authenticated;
