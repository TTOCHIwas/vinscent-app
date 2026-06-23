alter table public.daily_questions
  drop constraint if exists daily_questions_assigned_date_not_future;

drop policy if exists "couple_expressions_select_member"
  on public.couple_expressions;

create policy "couple_expressions_select_member"
  on public.couple_expressions
  for select
  to authenticated
  using (
    private.is_readable_couple_member(couple_id, (select auth.uid()))
  );

drop policy if exists "couple_characters_select_member"
  on public.couple_characters;

create policy "couple_characters_select_member"
  on public.couple_characters
  for select
  to authenticated
  using (
    private.is_readable_couple_member(couple_id, (select auth.uid()))
  );

create or replace function private.is_current_user_character_storage_object(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select object_bucket_id = 'couple-characters'
    and exists (
      select 1
      from public.couples as c
      where (
          c.status = 'active'
          or (
            c.status = 'disconnected'
            and c.archive_expires_at is not null
            and c.archive_expires_at > now()
          )
        )
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and object_name in (
          c.id::text || '/current.png',
          c.id::text || '/current.json'
        )
    );
$$;

create or replace function public.get_couple_character()
returns table (
  couple_id uuid,
  image_path text,
  drawing_data_path text,
  updated_by uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  readable_couple public.couples%rowtype;
begin
  readable_couple := private.get_readable_couple_for_current_user();

  return query
    select
      cc.couple_id,
      cc.image_path,
      cc.drawing_data_path,
      cc.updated_by,
      cc.created_at,
      cc.updated_at
    from public.couple_characters as cc
    where cc.couple_id = readable_couple.id;
end;
$$;

create or replace function public.get_couple_expression_summary_for_date(
  target_date date
)
returns table (
  expression_type text,
  sent_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  readable_couple public.couples%rowtype;
  current_couple_date date;
begin
  readable_couple := private.get_readable_couple_for_current_user();
  current_couple_date := private.current_date_in_timezone(readable_couple.timezone);

  if readable_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if target_date is null
    or target_date < readable_couple.relationship_start_date
    or target_date > current_couple_date
  then
    return query
      select expression_types.expression_type, 0::integer
      from (
        values
          ('miss_you'::text, 1),
          ('thanks'::text, 2),
          ('feeling_down'::text, 3),
          ('cheer_up'::text, 4)
      ) as expression_types(expression_type, sort_order)
      order by sort_order;

    return;
  end if;

  return query
    with expression_types(expression_type, sort_order) as (
      values
        ('miss_you'::text, 1),
        ('thanks'::text, 2),
        ('feeling_down'::text, 3),
        ('cheer_up'::text, 4)
    ),
    expression_counts as (
      select
        ce.expression_type,
        count(*)::integer as sent_count
      from public.couple_expressions as ce
      where ce.couple_id = readable_couple.id
        and (ce.sent_at at time zone readable_couple.timezone)::date = target_date
      group by ce.expression_type
    )
    select
      expression_types.expression_type,
      coalesce(expression_counts.sent_count, 0)
    from expression_types
    left join expression_counts
      on expression_counts.expression_type = expression_types.expression_type
    order by expression_types.sort_order;
end;
$$;

create or replace function private.get_or_assign_today_daily_question()
returns public.daily_questions
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_couple public.couples%rowtype;
  app_today date;
  target_daily_question public.daily_questions%rowtype;
  assignment_count integer;
  active_question_count integer;
  selected_question_id uuid;
begin
  active_couple := private.get_active_couple_for_current_user();
  app_today := private.current_date_in_timezone(active_couple.timezone);

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('daily_question'),
    hashtext(active_couple.id::text || ':' || app_today::text)
  );

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = active_couple.id
    and dq.assigned_date = app_today
  limit 1;

  if found then
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

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = active_couple.id
    and dq.assigned_date = app_today
  limit 1;

  if not found then
    perform private.raise_app_error('question_assignment_failed');
  end if;

  return target_daily_question;
end;
$$;

create or replace function public.get_daily_question_answer_state_for_date(
  target_date date
)
returns table (
  daily_question_id uuid,
  couple_id uuid,
  question_id uuid,
  question_text text,
  question_source text,
  question_category text,
  question_mood text,
  assigned_date date,
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
  readable_couple public.couples%rowtype;
  current_couple_date date;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  readable_couple := private.get_readable_couple_for_current_user();
  current_couple_date := private.current_date_in_timezone(readable_couple.timezone);

  if readable_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if target_date is null
    or target_date < readable_couple.relationship_start_date
    or target_date > current_couple_date
  then
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
    from public.daily_questions as dq
    join public.questions as q
      on q.id = dq.question_id
    join lateral private.get_today_question_answer_state(
      dq.id,
      current_user_id
    ) as answer_state
      on true
    where dq.couple_id = readable_couple.id
      and dq.assigned_date = target_date
    limit 1;
end;
$$;

revoke execute on function private.is_current_user_character_storage_object(text, text)
  from public, anon, authenticated;
revoke execute on function private.get_or_assign_today_daily_question()
  from public, anon, authenticated;
