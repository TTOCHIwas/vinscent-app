create table public.daily_question_answers (
  id uuid primary key default gen_random_uuid(),
  daily_question_id uuid not null references public.daily_questions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  answer_text text not null,
  answered_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint daily_question_answers_text_length
    check (char_length(btrim(answer_text)) between 1 and 500),
  constraint daily_question_answers_daily_question_user_unique
    unique (daily_question_id, user_id)
);

create index daily_question_answers_daily_question_id_idx
  on public.daily_question_answers (daily_question_id);

create index daily_question_answers_user_id_idx
  on public.daily_question_answers (user_id);

alter table public.daily_question_answers enable row level security;

create trigger daily_question_answers_set_updated_at
  before update on public.daily_question_answers
  for each row
  execute function public.set_updated_at();

create or replace function private.get_or_assign_today_daily_question()
returns public.daily_questions
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_couple public.couples%rowtype;
  app_today date := private.current_app_date();
  target_daily_question public.daily_questions%rowtype;
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

create or replace function private.get_today_question_answer_state(
  target_daily_question_id uuid,
  requested_user_id uuid
)
returns table (
  daily_question_id uuid,
  status text,
  my_answer_id uuid,
  my_answer_text text,
  my_answer_answered_at timestamptz,
  my_answer_updated_at timestamptz,
  partner_answer_exists boolean,
  answer_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
    select
      dq.id,
      dq.status,
      my_answer.id,
      my_answer.answer_text,
      my_answer.answered_at,
      my_answer.updated_at,
      exists (
        select 1
        from public.daily_question_answers as partner_answer
        where partner_answer.daily_question_id = dq.id
          and partner_answer.user_id <> requested_user_id
      ),
      (
        select count(*)::integer
        from public.daily_question_answers as counted_answer
        where counted_answer.daily_question_id = dq.id
      )
    from public.daily_questions as dq
    left join public.daily_question_answers as my_answer
      on my_answer.daily_question_id = dq.id
      and my_answer.user_id = requested_user_id
    where dq.id = target_daily_question_id;
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
  target_daily_question public.daily_questions%rowtype;
begin
  target_daily_question := private.get_or_assign_today_daily_question();

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
    where dq.id = target_daily_question.id;
end;
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
  answer_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  target_daily_question public.daily_questions%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  target_daily_question := private.get_or_assign_today_daily_question();

  return query
    select *
    from private.get_today_question_answer_state(
      target_daily_question.id,
      current_user_id
    );
end;
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
  answer_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  target_daily_question public.daily_questions%rowtype;
  normalized_answer text := btrim($1);
  saved_answer_count integer;
  next_status text;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  target_daily_question := private.get_or_assign_today_daily_question();

  perform pg_advisory_xact_lock(
    hashtext('daily_question_answer'),
    hashtext(target_daily_question.id::text)
  );

  if normalized_answer is null or char_length(normalized_answer) = 0 then
    perform private.raise_app_error('answer_required');
  end if;

  if char_length(normalized_answer) > 500 then
    perform private.raise_app_error('answer_too_long');
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
  where dqa.daily_question_id = target_daily_question.id;

  next_status := case
    when saved_answer_count >= 2 then 'completed'
    when saved_answer_count = 1 then 'answered_by_one'
    else 'pending'
  end;

  update public.daily_questions as dq
  set status = next_status
  where dq.id = target_daily_question.id
  returning dq.* into target_daily_question;

  return query
    select *
    from private.get_today_question_answer_state(
      target_daily_question.id,
      current_user_id
    );
end;
$$;

revoke execute on function private.get_or_assign_today_daily_question()
  from public, anon, authenticated;
revoke execute on function private.get_today_question_answer_state(uuid, uuid)
  from public, anon, authenticated;

revoke execute on function public.get_or_assign_today_question()
  from public, anon;
revoke execute on function public.get_today_question_answer_state()
  from public, anon;
revoke execute on function public.submit_today_question_answer(text)
  from public, anon;

grant execute on function public.get_or_assign_today_question()
  to authenticated;
grant execute on function public.get_today_question_answer_state()
  to authenticated;
grant execute on function public.submit_today_question_answer(text)
  to authenticated;
