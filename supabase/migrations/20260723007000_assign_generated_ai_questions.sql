drop index if exists public.ai_question_recommendations_one_pending_idx;

create index if not exists ai_question_recommendations_pending_couple_idx
  on public.ai_question_recommendations (couple_id, created_at, id)
  where status = 'pending';

create or replace function private.is_ai_foundation_complete(
  target_couple_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  active_curriculum_version integer;
  foundation_question_count integer;
  completed_foundation_count integer;
begin
  select aiqc.version, aiqc.question_count
  into active_curriculum_version, foundation_question_count
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if active_curriculum_version is null then
    return false;
  end if;

  select count(*)::integer
  into completed_foundation_count
  from private.completed_ai_foundation_question_ids(
    target_couple_id,
    active_curriculum_version
  );

  return completed_foundation_count >= foundation_question_count;
end;
$$;

create or replace function private.ai_generated_question_job_type(
  target_couple_id uuid
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not private.is_ai_foundation_complete(target_couple_id) then null
    when private.is_ai_personalization_enabled(target_couple_id)
      then 'generate_personalized_question'
    else 'generate_general_question'
  end;
$$;

create or replace function private.ensure_ai_question_job_for_story_loop(
  target_couple_id uuid,
  target_story_loop_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_job_type text;
  deduplication_prefix text;
  existing_job_id uuid;
  previous_job_count integer;
  source_question record;
  next_available_at timestamptz;
begin
  if not private.have_all_couple_members_granted_ai_consent(
    target_couple_id
  ) then
    return null;
  end if;

  target_job_type := private.ai_generated_question_job_type(
    target_couple_id
  );

  if target_job_type is null then
    return null;
  end if;

  deduplication_prefix := 'story-loop:'
    || target_story_loop_id::text
    || ':'
    || target_job_type
    || ':';

  select aipj.id
  into existing_job_id
  from public.ai_processing_jobs as aipj
  where aipj.couple_id = target_couple_id
    and aipj.job_type = target_job_type
    and aipj.status in ('pending', 'processing')
    and left(
      aipj.deduplication_key,
      char_length(deduplication_prefix)
    ) = deduplication_prefix
  order by aipj.created_at desc, aipj.id
  limit 1;

  if existing_job_id is not null then
    return existing_job_id;
  end if;

  select count(*)::integer
  into previous_job_count
  from public.ai_processing_jobs as aipj
  where aipj.couple_id = target_couple_id
    and left(
      aipj.deduplication_key,
      char_length(deduplication_prefix)
    ) = deduplication_prefix;

  select completed.source_type, completed.instance_id
  into source_question
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
  order by completed.completed_at desc, completed.instance_id
  limit 1;

  if not found then
    return null;
  end if;

  next_available_at := case
    when previous_job_count = 0 then now()
    else now() + (
      least(
        power(2::numeric, least(previous_job_count, 6))::integer,
        60
      ) * interval '1 minute'
    )
  end;

  return private.enqueue_ai_processing_job_source(
    target_couple_id,
    case
      when source_question.source_type = 'daily'
        then source_question.instance_id
    end,
    case
      when source_question.source_type = 'focused'
        then source_question.instance_id
    end,
    target_job_type,
    deduplication_prefix || (previous_job_count + 1)::text,
    next_available_at
  );
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

  if expected_job_type is null then
    return null;
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_question_recommendation'),
    hashtext(target_couple.id::text)
  );

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  from public.ai_runs as air, public.questions as q
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and air.id = aiqr.source_run_id
    and q.id = aiqr.question_id
    and (
      aiqr.expires_at <= now()
      or air.task <> expected_job_type
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

  select aiqr.id, aiqr.question_id
  into selected_recommendation_id, selected_question_id
  from public.ai_question_recommendations as aiqr
  join public.ai_runs as air on air.id = aiqr.source_run_id
  join public.questions as q on q.id = aiqr.question_id
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and aiqr.expires_at > now()
    and air.task = expected_job_type
    and q.source = 'ai'
    and q.personalized_for_couple_id = target_couple.id
    and q.is_active
    and not exists (
      select 1
      from public.daily_questions as used_dq
      where used_dq.couple_id = target_couple.id
        and used_dq.question_id = q.id
    )
  order by aiqr.created_at, aiqr.id
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

create or replace function private.publish_story_loop_question(
  target_couple public.couples,
  target_story_loop public.daily_story_loops,
  target_daily_question public.daily_questions,
  triggering_user_id uuid,
  triggering_card_id uuid
)
returns public.daily_story_loops
language plpgsql
security definer
set search_path = ''
as $$
declare
  finalized_story_loop public.daily_story_loops%rowtype;
begin
  if target_daily_question.id is null
    or target_daily_question.couple_id <> target_couple.id
    or target_daily_question.story_loop_id <> target_story_loop.id
  then
    perform private.raise_app_error('question_assignment_failed');
  end if;

  update public.daily_story_loops as dsl
  set
    status = case
      when target_daily_question.status = 'answered_by_one'
        then 'answered_by_one'
      when target_daily_question.status = 'completed'
        then 'completed'
      else 'question_generated'
    end,
    question_generated_at = coalesce(dsl.question_generated_at, now()),
    story_edit_locked_at = coalesce(dsl.story_edit_locked_at, now())
  where dsl.id = target_story_loop.id
  returning * into finalized_story_loop;

  insert into public.story_loop_notification_events (
    couple_id,
    story_loop_id,
    card_id,
    sender_user_id,
    receiver_user_id,
    event_type
  )
  select
    target_couple.id,
    target_story_loop.id,
    triggering_card_id,
    triggering_user_id,
    receiver_user_id,
    'question_generated'
  from unnest(array[target_couple.user_a_id, target_couple.user_b_id])
    as receiver_user_id
  where receiver_user_id is not null
    and not exists (
      select 1
      from public.story_loop_notification_events as existing_event
      where existing_event.story_loop_id = target_story_loop.id
        and existing_event.receiver_user_id = receiver_user_id
        and existing_event.event_type = 'question_generated'
    );

  return finalized_story_loop;
end;
$$;

create or replace function private.attach_pending_ai_question_to_waiting_loop(
  target_couple_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_couple public.couples%rowtype;
  target_story_loop public.daily_story_loops%rowtype;
  target_daily_question public.daily_questions%rowtype;
  triggering_card public.story_loop_cards%rowtype;
begin
  perform pg_advisory_xact_lock(
    hashtext('ai_waiting_story_loop'),
    hashtext(target_couple_id::text)
  );

  select c.*
  into target_couple
  from public.couples as c
  where c.id = target_couple_id
    and c.status = 'active'
    and c.user_b_id is not null;

  if not found then
    return null;
  end if;

  select dsl.*
  into target_story_loop
  from public.daily_story_loops as dsl
  where dsl.couple_id = target_couple.id
    and dsl.status = 'question_preparing'
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.story_loop_id = dsl.id
    )
    and (
      select count(*)
      from public.story_loop_cards as slc
      where slc.story_loop_id = dsl.id
    ) = 2
  order by dsl.couple_date, dsl.created_at, dsl.id
  limit 1
  for update;

  if not found then
    return null;
  end if;

  target_daily_question := private.assign_pending_ai_question_to_story_loop(
    target_couple,
    target_story_loop
  );

  if target_daily_question.id is null then
    return null;
  end if;

  select slc.*
  into triggering_card
  from public.story_loop_cards as slc
  where slc.story_loop_id = target_story_loop.id
  order by slc.submitted_at desc, slc.id
  limit 1;

  perform private.publish_story_loop_question(
    target_couple,
    target_story_loop,
    target_daily_question,
    triggering_card.author_user_id,
    triggering_card.id
  );

  return target_daily_question.id;
end;
$$;

create or replace function private.finalize_story_loop_after_card_pair(
  target_couple public.couples,
  target_story_loop public.daily_story_loops,
  triggering_user_id uuid,
  triggering_card_id uuid
)
returns table (
  story_loop_status text,
  question_generated boolean,
  daily_question_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  saved_card_count integer;
  finalized_story_loop public.daily_story_loops%rowtype;
  target_daily_question public.daily_questions%rowtype;
begin
  select count(*)::integer
  into saved_card_count
  from public.story_loop_cards as slc
  where slc.story_loop_id = target_story_loop.id;

  if saved_card_count <> 2 then
    return query
      select target_story_loop.status, false, null::uuid;
    return;
  end if;

  if private.is_ai_focused_foundation_in_progress(target_couple.id) then
    update public.daily_story_loops as dsl
    set
      status = 'card_only_completed',
      question_generated_at = null,
      story_edit_locked_at = coalesce(dsl.story_edit_locked_at, now())
    where dsl.id = target_story_loop.id
    returning * into finalized_story_loop;

    return query
      select finalized_story_loop.status, false, null::uuid;
    return;
  end if;

  if private.is_ai_foundation_complete(target_couple.id) then
    if not private.have_all_couple_members_granted_ai_consent(
      target_couple.id
    ) then
      update public.daily_story_loops as dsl
      set
        status = 'card_only_completed',
        question_generated_at = null,
        story_edit_locked_at = coalesce(dsl.story_edit_locked_at, now())
      where dsl.id = target_story_loop.id
      returning * into finalized_story_loop;

      return query
        select finalized_story_loop.status, false, null::uuid;
      return;
    end if;

    target_daily_question :=
      private.assign_pending_ai_question_to_story_loop(
        target_couple,
        target_story_loop
      );

    if target_daily_question.id is null then
      update public.daily_story_loops as dsl
      set
        status = 'question_preparing',
        question_generated_at = null,
        story_edit_locked_at = coalesce(dsl.story_edit_locked_at, now())
      where dsl.id = target_story_loop.id
      returning * into finalized_story_loop;

      perform private.ensure_ai_question_job_for_story_loop(
        target_couple.id,
        target_story_loop.id
      );

      return query
        select finalized_story_loop.status, false, null::uuid;
      return;
    end if;

    finalized_story_loop := private.publish_story_loop_question(
      target_couple,
      target_story_loop,
      target_daily_question,
      triggering_user_id,
      triggering_card_id
    );

    return query
      select finalized_story_loop.status, true, target_daily_question.id;
    return;
  end if;

  target_daily_question := private.assign_question_to_story_loop(
    target_couple,
    target_story_loop
  );
  finalized_story_loop := private.publish_story_loop_question(
    target_couple,
    target_story_loop,
    target_daily_question,
    triggering_user_id,
    triggering_card_id
  );

  return query
    select finalized_story_loop.status, true, target_daily_question.id;
end;
$$;

revoke execute on function private.is_ai_foundation_complete(uuid)
  from public, anon, authenticated;
revoke execute on function private.ai_generated_question_job_type(uuid)
  from public, anon, authenticated;
revoke execute on function private.ensure_ai_question_job_for_story_loop(
  uuid,
  uuid
) from public, anon, authenticated;
revoke execute on function private.assign_pending_ai_question_to_story_loop(
  public.couples,
  public.daily_story_loops
) from public, anon, authenticated;
revoke execute on function private.publish_story_loop_question(
  public.couples,
  public.daily_story_loops,
  public.daily_questions,
  uuid,
  uuid
) from public, anon, authenticated;
revoke execute on function private.attach_pending_ai_question_to_waiting_loop(
  uuid
) from public, anon, authenticated;

alter function public.record_ai_question_recommendation(
  uuid,
  uuid,
  uuid,
  text
) rename to record_ai_question_recommendation_single_pending_v6;

revoke execute on function
  public.record_ai_question_recommendation_single_pending_v6(
    uuid,
    uuid,
    uuid,
    text
  ) from public, anon, authenticated, service_role;

create or replace function public.record_ai_question_recommendation(
  requested_run_id uuid,
  requested_couple_id uuid,
  requested_question_id uuid,
  requested_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_reason text := btrim(requested_reason);
  active_curriculum_version integer;
  recommendation_id uuid;
begin
  if requested_run_id is null
    or requested_couple_id is null
    or requested_question_id is null
    or normalized_reason is null
    or char_length(normalized_reason) not between 1 and 500
  then
    perform private.raise_app_error('invalid_ai_question_recommendation');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_question_recommendation'),
    hashtext(requested_couple_id::text)
  );

  if not private.have_all_couple_members_granted_ai_consent(
    requested_couple_id
  ) then
    perform private.raise_app_error('ai_consent_required');
  end if;

  perform 1
  from public.ai_runs as air
  where air.id = requested_run_id
    and air.couple_id = requested_couple_id
    and air.task = 'select_curated_question'
    and air.status = 'succeeded'
    and air.safety_status = 'passed';

  if not found then
    perform private.raise_app_error('invalid_ai_question_run');
  end if;

  select aiqc.version
  into active_curriculum_version
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  perform 1
  from public.questions as q
  where q.id = requested_question_id
    and q.source = 'curated'
    and q.curriculum_version = active_curriculum_version
    and q.is_active
    and not private.is_ai_foundation_question_completed(
      requested_couple_id,
      q.id
    )
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.couple_id = requested_couple_id
        and dq.question_id = q.id
    );

  if not found then
    perform private.raise_app_error('invalid_ai_question_candidate');
  end if;

  update public.ai_question_recommendations as aiqr
  set status = 'cancelled'
  from public.ai_runs as air
  where aiqr.couple_id = requested_couple_id
    and aiqr.status = 'pending'
    and air.id = aiqr.source_run_id
    and air.task = 'select_curated_question';

  insert into public.ai_question_recommendations (
    couple_id,
    question_id,
    source_run_id,
    reason
  )
  values (
    requested_couple_id,
    requested_question_id,
    requested_run_id,
    normalized_reason
  )
  returning id into recommendation_id;

  return recommendation_id;
end;
$$;

revoke execute on function public.record_ai_question_recommendation(
  uuid,
  uuid,
  uuid,
  text
) from public, anon, authenticated;
grant execute on function public.record_ai_question_recommendation(
  uuid,
  uuid,
  uuid,
  text
) to service_role;

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
  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.story_loop_id = target_story_loop.id
  for update;

  if found then
    return target_daily_question;
  end if;

  if private.is_ai_foundation_complete(target_couple.id) then
    perform private.raise_app_error('question_not_ready');
  end if;

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  from public.ai_runs as air
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and air.id = aiqr.source_run_id
    and air.task = 'select_curated_question'
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
    );

  select aiqr.id, aiqr.question_id
  into selected_recommendation_id, selected_question_id
  from public.ai_question_recommendations as aiqr
  join public.ai_runs as air on air.id = aiqr.source_run_id
  join public.questions as q on q.id = aiqr.question_id
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and aiqr.expires_at > now()
    and air.task = 'select_curated_question'
    and q.source = 'curated'
    and q.is_active
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
      and aiqc.status = 'active'
    where q.source = 'curated'
      and q.is_active
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

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id
    and dq.assigned_date = target_story_loop.couple_date
  for update;

  if not found or target_daily_question.story_loop_id <> target_story_loop.id then
    perform private.raise_app_error('question_assignment_failed');
  end if;

  if selected_recommendation_id is not null then
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
