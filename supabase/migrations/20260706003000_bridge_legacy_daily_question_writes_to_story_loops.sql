create or replace function private.get_or_create_question_generated_story_loop(
  target_couple_id uuid,
  target_couple_date date,
  target_created_at timestamptz
)
returns public.daily_story_loops
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_loop public.daily_story_loops%rowtype;
begin
  select *
  into target_loop
  from public.daily_story_loops
  where daily_story_loops.couple_id = target_couple_id
    and daily_story_loops.couple_date = target_couple_date
  limit 1;

  if found then
    if target_loop.status = 'waiting_partner_card' then
      update public.daily_story_loops
      set
        status = 'question_generated',
        question_generated_at = coalesce(
          daily_story_loops.question_generated_at,
          target_created_at
        ),
        story_edit_locked_at = coalesce(
          daily_story_loops.story_edit_locked_at,
          target_created_at
        )
      where daily_story_loops.id = target_loop.id
      returning * into target_loop;
    end if;

    return target_loop;
  end if;

  insert into public.daily_story_loops (
    couple_id,
    couple_date,
    status,
    question_generated_at,
    story_edit_locked_at,
    created_at,
    updated_at
  )
  values (
    target_couple_id,
    target_couple_date,
    'question_generated',
    target_created_at,
    target_created_at,
    target_created_at,
    target_created_at
  )
  on conflict on constraint daily_story_loops_couple_date_unique
  do nothing;

  select *
  into target_loop
  from public.daily_story_loops
  where daily_story_loops.couple_id = target_couple_id
    and daily_story_loops.couple_date = target_couple_date
  limit 1;

  if not found then
    raise exception 'question_generated_story_loop_bridge_failed';
  end if;

  return target_loop;
end;
$$;

create or replace function private.get_or_assign_daily_question_for_couple(
  requested_couple_id uuid,
  requested_target_date date
)
returns public.daily_questions
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_couple public.couples%rowtype;
  target_daily_question public.daily_questions%rowtype;
  target_story_loop public.daily_story_loops%rowtype;
  assignment_count integer;
  active_question_count integer;
  selected_question_id uuid;
begin
  if requested_couple_id is null or requested_target_date is null then
    perform private.raise_app_error('invalid_daily_question_target');
  end if;

  select *
  into target_couple
  from public.couples as c
  where c.id = requested_couple_id
    and c.status = 'active';

  if not found then
    perform private.raise_app_error('active_couple_required');
  end if;

  if target_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if requested_target_date < target_couple.relationship_start_date
    or requested_target_date > private.current_date_in_timezone(target_couple.timezone)
  then
    perform private.raise_app_error('invalid_daily_question_target');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('daily_question'),
    hashtext(target_couple.id::text || ':' || requested_target_date::text)
  );

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id
    and dq.assigned_date = requested_target_date
  limit 1;

  if found then
    if target_daily_question.story_loop_id is null then
      target_story_loop := private.get_or_create_question_generated_story_loop(
        target_daily_question.couple_id,
        target_daily_question.assigned_date,
        target_daily_question.created_at
      );

      update public.daily_questions as dq
      set story_loop_id = target_story_loop.id
      where dq.id = target_daily_question.id
      returning dq.* into target_daily_question;
    end if;

    if target_daily_question.story_loop_id is null then
      raise exception 'question_story_loop_bridge_failed';
    end if;

    return target_daily_question;
  end if;

  select count(*)
  into active_question_count
  from public.questions as q
  where q.source = 'curated'
    and q.is_active = true;

  if active_question_count = 0 then
    perform private.raise_app_error('question_pool_empty');
  end if;

  select count(*)
  into assignment_count
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id;

  select q.id
  into selected_question_id
  from public.questions as q
  where q.source = 'curated'
    and q.is_active = true
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.couple_id = target_couple.id
        and dq.question_id = q.id
    )
  order by q.created_at, q.id
  limit 1;

  if selected_question_id is null then
    select q.id
    into selected_question_id
    from public.questions as q
    where q.source = 'curated'
      and q.is_active = true
    order by q.created_at, q.id
    offset assignment_count % active_question_count
    limit 1;
  end if;

  target_story_loop := private.get_or_create_question_generated_story_loop(
    target_couple.id,
    requested_target_date,
    now()
  );

  insert into public.daily_questions (
    couple_id,
    question_id,
    assigned_date,
    story_loop_id
  )
  values (
    target_couple.id,
    selected_question_id,
    requested_target_date,
    target_story_loop.id
  )
  on conflict on constraint daily_questions_couple_date_unique do nothing;

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id
    and dq.assigned_date = requested_target_date
  limit 1;

  if not found then
    perform private.raise_app_error('question_assignment_failed');
  end if;

  if target_daily_question.story_loop_id is null then
    target_story_loop := private.get_or_create_question_generated_story_loop(
      target_daily_question.couple_id,
      target_daily_question.assigned_date,
      target_daily_question.created_at
    );

    update public.daily_questions as dq
    set story_loop_id = target_story_loop.id
    where dq.id = target_daily_question.id
    returning dq.* into target_daily_question;
  end if;

  if target_daily_question.story_loop_id is null then
    raise exception 'question_story_loop_bridge_failed';
  end if;

  return target_daily_question;
end;
$$;

revoke execute on function private.get_or_create_question_generated_story_loop(
  uuid,
  date,
  timestamptz
) from public, anon, authenticated;
