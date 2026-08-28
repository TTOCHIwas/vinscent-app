create or replace function private.assign_curated_fallback_question_to_story_loop(
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
begin
  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.story_loop_id = target_story_loop.id
  for update;

  if found then
    return target_daily_question;
  end if;

  select q.id
  into selected_question_id
  from public.questions as q
  left join public.ai_question_curricula as aiqc
    on aiqc.version = q.curriculum_version
    and aiqc.status = 'active'
  left join lateral (
    select max(question_usage.used_at) as last_used_at
    from (
      select dq.created_at as used_at
      from public.daily_questions as dq
      where dq.couple_id = target_couple.id
        and dq.question_id = q.id

      union all

      select greatest(aifq.updated_at, aifq.created_at)
      from public.ai_focused_questions as aifq
      where aifq.couple_id = target_couple.id
        and aifq.question_id = q.id
        and aifq.status = 'completed'
    ) as question_usage
  ) as usage on true
  where q.source = 'curated'
    and q.is_active
  order by
    usage.last_used_at nulls first,
    case when aiqc.version is null then 1 else 0 end,
    q.curriculum_version desc nulls last,
    q.curriculum_position nulls last,
    q.created_at,
    q.id
  limit 1;

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
  then
    return null;
  end if;

  return target_daily_question;
end;
$$;

revoke execute on function
  private.assign_curated_fallback_question_to_story_loop(
    public.couples,
    public.daily_story_loops
  ) from public, anon, authenticated;

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
  target_couple public.couples%rowtype;
  target_story_loop public.daily_story_loops%rowtype;
  target_daily_question public.daily_questions%rowtype;
  triggering_card public.story_loop_cards%rowtype;
  target_job_type text;
  deduplication_prefix text;
  existing_job_id uuid;
  previous_job_count integer;
  terminal_failure_count integer;
  source_question record;
  next_available_at timestamptz;
begin
  if target_couple_id is null or target_story_loop_id is null then
    return null;
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_story_loop_question_job'),
    hashtext(target_story_loop_id::text)
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
  where dsl.id = target_story_loop_id
    and dsl.couple_id = target_couple.id
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
  for update;

  if not found then
    return null;
  end if;

  if not private.have_all_couple_members_granted_ai_consent(
    target_couple.id
  ) then
    return null;
  end if;

  target_job_type := private.ai_generated_question_job_type(
    target_couple.id
  );

  if target_job_type is null then
    return null;
  end if;

  deduplication_prefix := 'story-loop:'
    || target_story_loop.id::text
    || ':'
    || target_job_type
    || ':';

  select aipj.id
  into existing_job_id
  from public.ai_processing_jobs as aipj
  where aipj.couple_id = target_couple.id
    and aipj.job_type = target_job_type
    and aipj.status = 'processing'
    and left(
      aipj.deduplication_key,
      char_length(deduplication_prefix)
    ) = deduplication_prefix
  order by aipj.created_at desc, aipj.id
  limit 1;

  if existing_job_id is not null then
    return existing_job_id;
  end if;

  select
    count(*)::integer,
    count(*) filter (where aipj.status = 'failed')::integer
  into previous_job_count, terminal_failure_count
  from public.ai_processing_jobs as aipj
  where aipj.couple_id = target_couple.id
    and aipj.job_type = target_job_type
    and left(
      aipj.deduplication_key,
      char_length(deduplication_prefix)
    ) = deduplication_prefix;

  if terminal_failure_count >= 2 then
    update public.ai_processing_jobs as aipj
    set
      status = 'cancelled',
      completed_at = now(),
      last_error = 'curated_question_fallback'
    where aipj.couple_id = target_couple.id
      and aipj.job_type = target_job_type
      and aipj.status = 'pending'
      and left(
        aipj.deduplication_key,
        char_length(deduplication_prefix)
      ) = deduplication_prefix;

    target_daily_question :=
      private.assign_curated_fallback_question_to_story_loop(
        target_couple,
        target_story_loop
      );

    if target_daily_question.id is null then
      update public.daily_story_loops as dsl
      set
        status = 'card_only_completed',
        question_generated_at = null,
        story_edit_locked_at = coalesce(dsl.story_edit_locked_at, now())
      where dsl.id = target_story_loop.id
        and dsl.status = 'question_preparing';

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

    return null;
  end if;

  select aipj.id
  into existing_job_id
  from public.ai_processing_jobs as aipj
  where aipj.couple_id = target_couple.id
    and aipj.job_type = target_job_type
    and aipj.status = 'pending'
    and left(
      aipj.deduplication_key,
      char_length(deduplication_prefix)
    ) = deduplication_prefix
  order by aipj.created_at desc, aipj.id
  limit 1;

  if existing_job_id is not null then
    return existing_job_id;
  end if;

  select completed.source_type, completed.instance_id
  into source_question
  from (
    select
      'daily'::text as source_type,
      dq.id as instance_id,
      greatest(dq.updated_at, dq.created_at) as completed_at
    from public.daily_questions as dq
    where dq.couple_id = target_couple.id
      and dq.status = 'completed'

    union all

    select
      'focused'::text,
      aifq.id,
      greatest(aifq.updated_at, aifq.created_at)
    from public.ai_focused_questions as aifq
    where aifq.couple_id = target_couple.id
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
    target_couple.id,
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

revoke execute on function private.ensure_ai_question_job_for_story_loop(
  uuid,
  uuid
) from public, anon, authenticated;
