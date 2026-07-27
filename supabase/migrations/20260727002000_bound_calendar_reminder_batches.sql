drop function if exists public.get_due_couple_calendar_event_reminders(
  timestamptz,
  integer
);

create function public.get_due_couple_calendar_event_reminders(
  requested_run_at timestamptz,
  requested_lookback_minutes integer,
  requested_limit integer default 100
)
returns table (
  source_id uuid,
  event_id uuid,
  couple_id uuid,
  receiver_user_id uuid,
  title text,
  occurrence_date date,
  offset_days integer,
  scheduled_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if requested_run_at is null
    or requested_lookback_minutes is null
    or requested_lookback_minutes < 1
    or requested_lookback_minutes > 60
    or requested_limit is null
    or requested_limit < 1
    or requested_limit > 200
  then
    perform private.raise_app_error('invalid_calendar_reminder_window');
  end if;

  return query
    with reminder_candidates as (
      select
        calendar_event.id as event_id,
        calendar_event.couple_id,
        reminder.user_id as receiver_user_id,
        calendar_event.title,
        reminder.offset_days,
        reminder.reminder_time,
        couple.timezone,
        calendar_event.repeat_rule,
        calendar_event.event_date,
        candidate_year.target_year
      from public.couple_calendar_event_reminders as reminder
      join public.couple_calendar_events as calendar_event
        on calendar_event.id = reminder.event_id
        and calendar_event.couple_id = reminder.couple_id
      join public.couples as couple
        on couple.id = calendar_event.couple_id
        and couple.status = 'active'
      cross join lateral generate_series(
        extract(
          year from (
            (
              requested_run_at
              - make_interval(mins => requested_lookback_minutes)
            ) at time zone couple.timezone
          )::date + reminder.offset_days
        )::integer,
        extract(
          year from (
            requested_run_at at time zone couple.timezone
          )::date + reminder.offset_days
        )::integer
      ) as candidate_year(target_year)
      where reminder.is_enabled
    ),
    resolved_occurrences as (
      select
        reminder_candidates.*,
        case
          when repeat_rule = 'none' then event_date
          else private.calendar_event_occurrence_date(
            event_date,
            target_year
          )
        end as occurrence_date
      from reminder_candidates
    ),
    due_reminders as (
      select
        resolved_occurrences.*,
        (
          (
            resolved_occurrences.occurrence_date
              - resolved_occurrences.offset_days
          )::date + resolved_occurrences.reminder_time
        ) at time zone resolved_occurrences.timezone as scheduled_at
      from resolved_occurrences
      where resolved_occurrences.occurrence_date
        >= resolved_occurrences.event_date
    ),
    notification_candidates as (
      select
        md5(
          due_reminders.event_id::text
          || ':' || due_reminders.receiver_user_id::text
          || ':' || due_reminders.occurrence_date::text
        )::uuid as source_id,
        due_reminders.event_id,
        due_reminders.couple_id,
        due_reminders.receiver_user_id,
        due_reminders.title,
        due_reminders.occurrence_date,
        due_reminders.offset_days,
        due_reminders.scheduled_at
      from due_reminders
      where due_reminders.scheduled_at
          >= requested_run_at
            - make_interval(mins => requested_lookback_minutes)
        and due_reminders.scheduled_at < requested_run_at
    )
    select
      candidate.source_id,
      candidate.event_id,
      candidate.couple_id,
      candidate.receiver_user_id,
      candidate.title,
      candidate.occurrence_date,
      candidate.offset_days,
      candidate.scheduled_at
    from notification_candidates as candidate
    where not exists (
      select 1
      from public.push_notification_dispatches as dispatch
      where dispatch.notification_type = 'calendar_event_reminder'
        and dispatch.source_id = candidate.source_id
        and dispatch.receiver_user_id = candidate.receiver_user_id
        and (
          dispatch.status <> 'processing'
          or dispatch.claimed_at >= requested_run_at - interval '5 minutes'
        )
    )
    order by candidate.scheduled_at, candidate.event_id
    limit requested_limit;
end;
$$;

revoke execute on function public.get_due_couple_calendar_event_reminders(
  timestamptz,
  integer,
  integer
) from public, anon, authenticated;

grant execute on function public.get_due_couple_calendar_event_reminders(
  timestamptz,
  integer,
  integer
) to service_role;
