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
  app_today date := private.current_app_date();
  assignment_count integer;
  active_question_count integer;
  selected_question_id uuid;
begin
  active_couple := private.get_active_couple_for_current_user();

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('daily_question'),
    hashtext(active_couple.id::text || ':' || app_today::text)
  );

  if exists (
    select 1
    from public.daily_questions as dq
    where dq.couple_id = active_couple.id
      and dq.assigned_date = app_today
  ) then
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
      join public.questions as q
        on q.id = dq.question_id
      where dq.couple_id = active_couple.id
        and dq.assigned_date = app_today;

    return;
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
  where dq.couple_id = active_couple.id;

  select q.id
  into selected_question_id
  from public.questions as q
  where q.source = 'curated'
    and q.is_active = true
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.couple_id = active_couple.id
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

  insert into public.daily_questions (
    couple_id,
    question_id,
    assigned_date
  )
  values (
    active_couple.id,
    selected_question_id,
    app_today
  )
  on conflict on constraint daily_questions_couple_date_unique do nothing;

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
    join public.questions as q
      on q.id = dq.question_id
    where dq.couple_id = active_couple.id
      and dq.assigned_date = app_today;
end;
$$;

revoke execute on function public.get_or_assign_today_question()
  from public, anon;

grant execute on function public.get_or_assign_today_question()
  to authenticated;
