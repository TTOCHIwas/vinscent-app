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

  insert into public.daily_questions (
    couple_id,
    question_id,
    assigned_date
  )
  values (
    target_couple.id,
    selected_question_id,
    requested_target_date
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

  return target_daily_question;
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
begin
  active_couple := private.get_active_couple_for_current_user();

  return private.get_or_assign_daily_question_for_couple(
    active_couple.id,
    private.current_date_in_timezone(active_couple.timezone)
  );
end;
$$;

create or replace function public.get_or_assign_daily_question_for_couple(
  requested_couple_id uuid,
  requested_target_date date
)
returns table (
  daily_question_id uuid,
  couple_id uuid,
  question_id uuid,
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
  target_daily_question := private.get_or_assign_daily_question_for_couple(
    requested_couple_id,
    requested_target_date
  );

  return query
    select
      target_daily_question.id,
      target_daily_question.couple_id,
      target_daily_question.question_id,
      target_daily_question.assigned_date,
      target_daily_question.status;
end;
$$;

create or replace function public.get_daily_question_answer_notification_context(
  requested_answer_id uuid
)
returns table (
  answer_id uuid,
  daily_question_id uuid,
  couple_id uuid,
  sender_user_id uuid,
  receiver_user_id uuid,
  assigned_date date,
  answered_at timestamptz,
  question_status text
)
language sql
security definer
set search_path = ''
as $$
  select
    dqa.id,
    dqa.daily_question_id,
    dq.couple_id,
    dqa.user_id,
    case
      when c.user_a_id = dqa.user_id then c.user_b_id
      else c.user_a_id
    end,
    dq.assigned_date,
    dqa.answered_at,
    dq.status
  from public.daily_question_answers as dqa
  join public.daily_questions as dq
    on dq.id = dqa.daily_question_id
  join public.couples as c
    on c.id = dq.couple_id
  where dqa.id = requested_answer_id
    and c.status = 'active';
$$;

revoke execute on function public.get_or_assign_daily_question_for_couple(uuid, date)
  from public, anon, authenticated;
revoke execute on function public.get_daily_question_answer_notification_context(uuid)
  from public, anon, authenticated;

grant execute on function public.get_or_assign_daily_question_for_couple(uuid, date)
  to service_role;
grant execute on function public.get_daily_question_answer_notification_context(uuid)
  to service_role;
