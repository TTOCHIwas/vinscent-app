create or replace function private.validate_couple_calendar_event_reminder_schedule()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_event public.couple_calendar_events%rowtype;
  couple_timezone text;
  scheduled_at timestamptz;
begin
  if not new.is_enabled then
    return new;
  end if;

  select calendar_event.*
  into target_event
  from public.couple_calendar_events as calendar_event
  where calendar_event.id = new.event_id;

  if not found then
    perform private.raise_app_error('calendar_event_not_found');
  end if;

  if target_event.repeat_rule = 'none' then
    select couple.timezone
    into couple_timezone
    from public.couples as couple
    where couple.id = target_event.couple_id;

    scheduled_at := (
      (target_event.event_date - new.offset_days) + new.reminder_time
    ) at time zone couple_timezone;

    if scheduled_at <= clock_timestamp() then
      perform private.raise_app_error('calendar_event_reminder_in_past');
    end if;
  end if;

  return new;
end;
$$;

revoke execute on function
  private.validate_couple_calendar_event_reminder_schedule()
from public, anon, authenticated;

drop trigger if exists validate_couple_calendar_event_reminder_schedule
on public.couple_calendar_event_reminders;

create trigger validate_couple_calendar_event_reminder_schedule
before insert or update of
  event_id,
  is_enabled,
  offset_days,
  reminder_time
on public.couple_calendar_event_reminders
for each row
execute function private.validate_couple_calendar_event_reminder_schedule();
