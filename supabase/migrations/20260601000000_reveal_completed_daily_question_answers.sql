drop function if exists public.submit_today_question_answer(text);
drop function if exists public.get_today_question_answer_state();
drop function if exists private.get_today_question_answer_state(uuid, uuid);

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
begin
  return query
    select
      dq.id,
      dq.status,
      my_answer.id,
      my_answer.answer_text,
      my_answer.answered_at,
      my_answer.updated_at,
      partner_answer.id is not null,
      case
        when my_answer.id is not null and partner_answer.id is not null
          then partner_answer.id
        else null
      end,
      case
        when my_answer.id is not null and partner_answer.id is not null
          then partner_answer.answer_text
        else null
      end,
      case
        when my_answer.id is not null and partner_answer.id is not null
          then partner_answer.answered_at
        else null
      end,
      case
        when my_answer.id is not null and partner_answer.id is not null
          then partner_answer.updated_at
        else null
      end,
      (
        select count(*)::integer
        from public.daily_question_answers as counted_answer
        where counted_answer.daily_question_id = dq.id
          and counted_answer.user_id in (c.user_a_id, c.user_b_id)
      )
    from public.daily_questions as dq
    join public.couples as c
      on c.id = dq.couple_id
    left join public.daily_question_answers as my_answer
      on my_answer.daily_question_id = dq.id
      and my_answer.user_id = requested_user_id
    left join public.daily_question_answers as partner_answer
      on partner_answer.daily_question_id = dq.id
      and partner_answer.user_id = case
        when c.user_a_id = requested_user_id then c.user_b_id
        when c.user_b_id = requested_user_id then c.user_a_id
        else null
      end
    where dq.id = target_daily_question_id
      and (
        c.user_a_id = requested_user_id
        or c.user_b_id = requested_user_id
      );
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
  target_daily_question public.daily_questions%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  target_daily_question := private.get_or_assign_today_daily_question();

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
  join public.daily_questions as dq
    on dq.id = dqa.daily_question_id
  join public.couples as c
    on c.id = dq.couple_id
  where dq.id = target_daily_question.id
    and dqa.user_id in (c.user_a_id, c.user_b_id);

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

revoke execute on function private.get_today_question_answer_state(uuid, uuid)
  from public, anon, authenticated;

revoke execute on function public.get_today_question_answer_state()
  from public, anon;
revoke execute on function public.submit_today_question_answer(text)
  from public, anon;

grant execute on function public.get_today_question_answer_state()
  to authenticated;
grant execute on function public.submit_today_question_answer(text)
  to authenticated;
