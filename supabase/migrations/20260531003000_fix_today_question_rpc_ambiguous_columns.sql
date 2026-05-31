create or replace function private.get_active_couple_for_current_user()
returns public.couples
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select *
  into active_couple
  from public.couples
  where public.couples.status = 'active'
    and (
      public.couples.user_a_id = current_user_id
      or public.couples.user_b_id = current_user_id
    )
  order by public.couples.created_at desc
  limit 1;

  if not found then
    perform private.raise_app_error('active_couple_required');
  end if;

  return active_couple;
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
  app_today date := private.current_app_date();
  assignment_count integer;
  active_question_count integer;
  selected_question_id uuid;
begin
  active_couple := private.get_active_couple_for_current_user();

  perform pg_advisory_xact_lock(
    hashtext('daily_question'),
    hashtext(active_couple.id::text || ':' || app_today::text)
  );

  if exists (
    select 1
    from public.daily_questions
    where public.daily_questions.couple_id = active_couple.id
      and public.daily_questions.assigned_date = app_today
  ) then
    return query
      select
        public.daily_questions.id,
        public.daily_questions.couple_id,
        public.questions.id,
        public.questions.question_text,
        public.questions.source,
        public.questions.category,
        public.questions.mood,
        public.daily_questions.assigned_date,
        public.daily_questions.status
      from public.daily_questions
      join public.questions
        on public.questions.id = public.daily_questions.question_id
      where public.daily_questions.couple_id = active_couple.id
        and public.daily_questions.assigned_date = app_today;

    return;
  end if;

  select count(*)
  into active_question_count
  from public.questions
  where public.questions.source = 'curated'
    and public.questions.is_active = true;

  if active_question_count = 0 then
    perform private.raise_app_error('question_pool_empty');
  end if;

  select count(*)
  into assignment_count
  from public.daily_questions
  where public.daily_questions.couple_id = active_couple.id;

  select public.questions.id
  into selected_question_id
  from public.questions
  where public.questions.source = 'curated'
    and public.questions.is_active = true
    and not exists (
      select 1
      from public.daily_questions
      where public.daily_questions.couple_id = active_couple.id
        and public.daily_questions.question_id = public.questions.id
    )
  order by public.questions.created_at, public.questions.id
  limit 1;

  if selected_question_id is null then
    select public.questions.id
    into selected_question_id
    from public.questions
    where public.questions.source = 'curated'
      and public.questions.is_active = true
    order by public.questions.created_at, public.questions.id
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
  on conflict (couple_id, assigned_date) do nothing;

  return query
    select
      public.daily_questions.id,
      public.daily_questions.couple_id,
      public.questions.id,
      public.questions.question_text,
      public.questions.source,
      public.questions.category,
      public.questions.mood,
      public.daily_questions.assigned_date,
      public.daily_questions.status
    from public.daily_questions
    join public.questions
      on public.questions.id = public.daily_questions.question_id
    where public.daily_questions.couple_id = active_couple.id
      and public.daily_questions.assigned_date = app_today;
end;
$$;

revoke execute on function private.get_active_couple_for_current_user()
  from public, anon, authenticated;
revoke execute on function public.get_or_assign_today_question()
  from public, anon;

grant execute on function public.get_or_assign_today_question()
  to authenticated;
