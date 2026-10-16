create function public.get_current_monthly_retrospective_availability()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.couples%rowtype;
  m date;
  next_month date;
begin
  if auth.uid() is null then
    perform private.raise_app_error('auth_required');
  end if;
  c := private.get_active_couple_for_current_user();
  m := (date_trunc('month', now() at time zone c.timezone) - interval '1 month')::date;
  next_month := (m + interval '1 month')::date;
  return jsonb_build_object(
    'couple_id', c.id,
    'month', m,
    'available_until', (m + interval '2 months')::timestamp at time zone c.timezone,
    'has_records',
      exists (
        select 1 from public.story_loop_cards card
        where card.couple_id = c.id and card.couple_date >= m and card.couple_date < next_month
      ) or exists (
        select 1 from public.daily_questions question
        join public.daily_question_answers answer on answer.daily_question_id = question.id
        where question.couple_id = c.id and question.assigned_date >= m and question.assigned_date < next_month
          and answer.user_id in (c.user_a_id, c.user_b_id)
      )
  );
end;
$$;

revoke all on function public.get_current_monthly_retrospective_availability() from public, anon;
grant execute on function public.get_current_monthly_retrospective_availability() to authenticated;
