create or replace function private.submit_current_story_loop_question_answer(
  expected_daily_question_id uuid,
  answer_text text
)
returns table (
  daily_question_id uuid,
  status text,
  my_answer_id uuid,
  my_answer_text text,
  my_answer_answered_at timestamptz,
  my_answer_updated_at timestamptz,
  partner_answer_exists boolean,
  partner_answer_id uuid,
  partner_answer_text text,
  partner_answer_answered_at timestamptz,
  partner_answer_updated_at timestamptz,
  answer_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  current_couple_date date;
  target_story_loop public.daily_story_loops%rowtype;
  target_daily_question public.daily_questions%rowtype;
  normalized_answer text := btrim(answer_text);
  saved_answer_count integer;
  next_status text;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  current_couple_date := private.current_date_in_timezone(
    active_couple.timezone
  );

  if current_couple_date < active_couple.relationship_start_date then
    perform private.raise_app_error('question_not_ready');
  end if;

  if normalized_answer is null or char_length(normalized_answer) = 0 then
    perform private.raise_app_error('answer_required');
  end if;

  if char_length(normalized_answer) > 500 then
    perform private.raise_app_error('answer_too_long');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('story_loop_question_answer'),
    hashtext(active_couple.id::text || ':' || current_couple_date::text)
  );

  select *
  into target_story_loop
  from public.daily_story_loops as dsl
  where dsl.couple_id = active_couple.id
    and dsl.couple_date = current_couple_date
  for update;

  if not found
    or target_story_loop.status not in (
      'question_generated',
      'answered_by_one',
      'completed'
    )
  then
    perform private.raise_app_error('question_not_ready');
  end if;

  select *
  into target_daily_question
  from public.daily_questions as dq
  where dq.story_loop_id = target_story_loop.id
    and (
      expected_daily_question_id is null
      or dq.id = expected_daily_question_id
    )
  for update;

  if not found then
    perform private.raise_app_error('question_not_ready');
  end if;

  insert into public.daily_question_answers (
    daily_question_id,
    user_id,
    answer_text
  )
  values (
    target_daily_question.id,
    current_user_id,
    normalized_answer
  )
  on conflict on constraint daily_question_answers_daily_question_user_unique
  do update
    set answer_text = excluded.answer_text;

  select count(*)::integer
  into saved_answer_count
  from public.daily_question_answers as dqa
  join public.daily_questions as dq
    on dq.id = dqa.daily_question_id
  join public.couples as c
    on c.id = dq.couple_id
  where dq.id = target_daily_question.id
    and dqa.user_id in (c.user_a_id, c.user_b_id);

  next_status := case
    when saved_answer_count >= 2 then 'completed'
    else 'answered_by_one'
  end;

  update public.daily_questions as dq
  set status = next_status
  where dq.id = target_daily_question.id
  returning dq.* into target_daily_question;

  update public.daily_story_loops as dsl
  set status = next_status
  where dsl.id = target_story_loop.id;

  return query
    select
      answer_state.daily_question_id,
      answer_state.status,
      answer_state.my_answer_id,
      answer_state.my_answer_text,
      answer_state.my_answer_answered_at,
      answer_state.my_answer_updated_at,
      answer_state.partner_answer_exists,
      answer_state.partner_answer_id,
      answer_state.partner_answer_text,
      answer_state.partner_answer_answered_at,
      answer_state.partner_answer_updated_at,
      answer_state.answer_count
    from private.get_today_question_answer_state(
      target_daily_question.id,
      current_user_id
    ) as answer_state;
end;
$$;

create or replace function public.submit_story_loop_question_answer(
  expected_daily_question_id uuid,
  answer_text text
)
returns table (
  daily_question_id uuid,
  status text,
  my_answer_id uuid,
  my_answer_text text,
  my_answer_answered_at timestamptz,
  my_answer_updated_at timestamptz,
  partner_answer_exists boolean,
  partner_answer_id uuid,
  partner_answer_text text,
  partner_answer_answered_at timestamptz,
  partner_answer_updated_at timestamptz,
  answer_count integer
)
language sql
security definer
set search_path = ''
as $$
  select *
  from private.submit_current_story_loop_question_answer(
    expected_daily_question_id,
    answer_text
  );
$$;

create or replace function public.submit_today_question_answer(
  answer_text text
)
returns table (
  daily_question_id uuid,
  status text,
  my_answer_id uuid,
  my_answer_text text,
  my_answer_answered_at timestamptz,
  my_answer_updated_at timestamptz,
  partner_answer_exists boolean,
  partner_answer_id uuid,
  partner_answer_text text,
  partner_answer_answered_at timestamptz,
  partner_answer_updated_at timestamptz,
  answer_count integer
)
language sql
security definer
set search_path = ''
as $$
  select *
  from private.submit_current_story_loop_question_answer(
    null,
    answer_text
  );
$$;

create or replace function public.get_today_question_answer_state()
returns table (
  daily_question_id uuid,
  status text,
  my_answer_id uuid,
  my_answer_text text,
  my_answer_answered_at timestamptz,
  my_answer_updated_at timestamptz,
  partner_answer_exists boolean,
  partner_answer_id uuid,
  partner_answer_text text,
  partner_answer_answered_at timestamptz,
  partner_answer_updated_at timestamptz,
  answer_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  current_couple_date date;
  target_daily_question public.daily_questions%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  current_couple_date := private.current_date_in_timezone(
    active_couple.timezone
  );

  if current_couple_date < active_couple.relationship_start_date then
    return;
  end if;

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  join public.daily_story_loops as dsl
    on dsl.id = dq.story_loop_id
  where dsl.couple_id = active_couple.id
    and dsl.couple_date = current_couple_date
    and dsl.status in (
      'question_generated',
      'answered_by_one',
      'completed'
    )
  limit 1;

  if not found then
    return;
  end if;

  return query
    select
      answer_state.daily_question_id,
      answer_state.status,
      answer_state.my_answer_id,
      answer_state.my_answer_text,
      answer_state.my_answer_answered_at,
      answer_state.my_answer_updated_at,
      answer_state.partner_answer_exists,
      answer_state.partner_answer_id,
      answer_state.partner_answer_text,
      answer_state.partner_answer_answered_at,
      answer_state.partner_answer_updated_at,
      answer_state.answer_count
    from private.get_today_question_answer_state(
      target_daily_question.id,
      current_user_id
    ) as answer_state;
end;
$$;

create or replace function public.get_or_assign_today_question()
returns table (
  daily_question_id uuid,
  couple_id uuid,
  question_id uuid,
  question_text text,
  question_source text,
  question_category text,
  question_mood text,
  assigned_date date,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_couple public.couples%rowtype;
  current_couple_date date;
begin
  active_couple := private.get_active_couple_for_current_user();

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  current_couple_date := private.current_date_in_timezone(
    active_couple.timezone
  );

  if current_couple_date < active_couple.relationship_start_date then
    return;
  end if;

  return query
    select
      dq.id,
      dq.couple_id,
      q.id,
      q.question_text,
      q.source,
      q.category,
      q.mood,
      dq.assigned_date,
      dq.status
    from public.daily_questions as dq
    join public.daily_story_loops as dsl
      on dsl.id = dq.story_loop_id
    join public.questions as q
      on q.id = dq.question_id
    where dsl.couple_id = active_couple.id
      and dsl.couple_date = current_couple_date
      and dsl.status in (
        'question_generated',
        'answered_by_one',
        'completed'
      );
end;
$$;

revoke execute on function private.submit_current_story_loop_question_answer(
  uuid,
  text
) from public, anon, authenticated;

revoke execute on function public.submit_story_loop_question_answer(uuid, text)
  from public, anon;
revoke execute on function public.get_today_question_answer_state()
  from public, anon;
revoke execute on function public.submit_today_question_answer(text)
  from public, anon;
revoke execute on function public.get_or_assign_today_question()
  from public, anon;

grant execute on function public.submit_story_loop_question_answer(uuid, text)
  to authenticated;
grant execute on function public.get_today_question_answer_state()
  to authenticated;
grant execute on function public.submit_today_question_answer(text)
  to authenticated;
grant execute on function public.get_or_assign_today_question()
  to authenticated;
