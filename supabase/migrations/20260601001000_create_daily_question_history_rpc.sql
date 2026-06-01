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
  active_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if target_date is null
    or target_date < active_couple.relationship_start_date
    or target_date > private.current_app_date()
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
    where dq.couple_id = active_couple.id
      and dq.assigned_date = target_date
    limit 1;
end;
$$;

revoke execute on function public.get_daily_question_answer_state_for_date(date)
  from public, anon;

grant execute on function public.get_daily_question_answer_state_for_date(date)
  to authenticated;
