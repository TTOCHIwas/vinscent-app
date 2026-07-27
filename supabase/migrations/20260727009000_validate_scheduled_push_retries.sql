create function public.is_push_notification_retry_eligible(
  requested_notification_type text,
  requested_source_id uuid,
  requested_receiver_user_id uuid,
  requested_data jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_notification_type text :=
    btrim(requested_notification_type);
  target_event_id uuid;
  target_occurrence_date date;
begin
  if requested_source_id is null
    or requested_receiver_user_id is null
    or requested_data is null
    or jsonb_typeof(requested_data) <> 'object'
  then
    return false;
  end if;

  if normalized_notification_type = 'unanswered_reminder' then
    return exists (
      select 1
      from public.daily_questions as question
      join public.daily_story_loops as story_loop
        on story_loop.id = question.story_loop_id
        and story_loop.couple_id = question.couple_id
        and story_loop.couple_date = question.assigned_date
      join public.couples as couple
        on couple.id = question.couple_id
        and couple.status = 'active'
      left join public.user_notification_preferences as preference
        on preference.user_id = requested_receiver_user_id
      where question.id = requested_source_id
        and question.status in ('pending', 'answered_by_one')
        and story_loop.status in (
          'question_generated',
          'answered_by_one'
        )
        and requested_receiver_user_id in (
          couple.user_a_id,
          couple.user_b_id
        )
        and coalesce(preference.reminder_enabled, true)
        and not exists (
          select 1
          from public.daily_question_answers as answer
          where answer.daily_question_id = question.id
            and answer.user_id = requested_receiver_user_id
        )
    );
  end if;

  if normalized_notification_type = 'calendar_event_reminder' then
    begin
      target_event_id := nullif(requested_data ->> 'event_id', '')::uuid;
      target_occurrence_date :=
        nullif(requested_data ->> 'event_date', '')::date;
    exception
      when invalid_text_representation or datetime_field_overflow then
        return false;
    end;

    if target_event_id is null or target_occurrence_date is null then
      return false;
    end if;

    return exists (
      select 1
      from public.couple_calendar_events as calendar_event
      join public.couple_calendar_event_reminders as reminder
        on reminder.event_id = calendar_event.id
        and reminder.couple_id = calendar_event.couple_id
        and reminder.user_id = requested_receiver_user_id
        and reminder.is_enabled
      join public.couples as couple
        on couple.id = calendar_event.couple_id
        and couple.status = 'active'
      where calendar_event.id = target_event_id
        and requested_receiver_user_id in (
          couple.user_a_id,
          couple.user_b_id
        )
        and target_occurrence_date
          >= (now() at time zone couple.timezone)::date
        and (
          (
            calendar_event.repeat_rule = 'none'
            and calendar_event.event_date = target_occurrence_date
          )
          or (
            calendar_event.repeat_rule = 'yearly'
            and private.calendar_event_occurrence_date(
              calendar_event.event_date,
              extract(year from target_occurrence_date)::integer
            ) = target_occurrence_date
          )
        )
        and md5(
          calendar_event.id::text
          || ':' || requested_receiver_user_id::text
          || ':' || target_occurrence_date::text
        )::uuid = requested_source_id
    );
  end if;

  return true;
end;
$$;

revoke execute on function public.is_push_notification_retry_eligible(
  text,
  uuid,
  uuid,
  jsonb
) from public, anon, authenticated;

grant execute on function public.is_push_notification_retry_eligible(
  text,
  uuid,
  uuid,
  jsonb
) to service_role;
