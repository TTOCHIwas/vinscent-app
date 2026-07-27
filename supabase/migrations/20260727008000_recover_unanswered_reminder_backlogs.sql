create function public.get_due_unanswered_question_reminders(
  requested_run_at timestamptz,
  requested_limit integer default 100
)
returns table (
  daily_question_id uuid,
  couple_id uuid,
  receiver_user_id uuid,
  assigned_date date
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if requested_run_at is null
    or requested_limit is null
    or requested_limit < 1
    or requested_limit > 200
  then
    raise exception 'invalid_unanswered_reminder_query';
  end if;

  return query
    with eligible_questions as (
      select
        question.id as daily_question_id,
        story_loop.couple_id,
        story_loop.couple_date as assigned_date,
        couple.user_a_id,
        couple.user_b_id,
        story_loop.question_generated_at
      from public.daily_story_loops as story_loop
      join public.daily_questions as question
        on question.story_loop_id = story_loop.id
        and question.couple_id = story_loop.couple_id
        and question.assigned_date = story_loop.couple_date
      join public.couples as couple
        on couple.id = story_loop.couple_id
        and couple.status = 'active'
      where story_loop.status in (
          'question_generated',
          'answered_by_one'
        )
        and question.status in ('pending', 'answered_by_one')
        and story_loop.question_generated_at
          <= requested_run_at - interval '60 minutes'
        and story_loop.question_generated_at
          >= requested_run_at - interval '24 hours'
    ),
    recipient_candidates as (
      select
        eligible.daily_question_id,
        eligible.couple_id,
        member.user_id as receiver_user_id,
        eligible.assigned_date,
        eligible.question_generated_at
      from eligible_questions as eligible
      cross join lateral (
        values (eligible.user_a_id), (eligible.user_b_id)
      ) as member(user_id)
    )
    select
      candidate.daily_question_id,
      candidate.couple_id,
      candidate.receiver_user_id,
      candidate.assigned_date
    from recipient_candidates as candidate
    left join public.user_notification_preferences as preference
      on preference.user_id = candidate.receiver_user_id
    where coalesce(preference.reminder_enabled, true)
      and not exists (
        select 1
        from public.daily_question_answers as answer
        where answer.daily_question_id = candidate.daily_question_id
          and answer.user_id = candidate.receiver_user_id
      )
      and not exists (
        select 1
        from public.push_notification_dispatches as dispatch
        where dispatch.notification_type = 'unanswered_reminder'
          and dispatch.source_id = candidate.daily_question_id
          and dispatch.receiver_user_id = candidate.receiver_user_id
      )
    order by
      candidate.question_generated_at,
      candidate.daily_question_id,
      candidate.receiver_user_id
    limit requested_limit;
end;
$$;

revoke execute on function public.get_due_unanswered_question_reminders(
  timestamptz,
  integer
) from public, anon, authenticated;

grant execute on function public.get_due_unanswered_question_reminders(
  timestamptz,
  integer
) to service_role;
