create or replace function private.disable_invalid_calendar_event_reminders()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  couple_timezone text;
begin
  if new.repeat_rule <> 'none' then
    return new;
  end if;

  select couple.timezone
  into couple_timezone
  from public.couples as couple
  where couple.id = new.couple_id;

  update public.couple_calendar_event_reminders as reminder
  set is_enabled = false
  where reminder.event_id = new.id
    and reminder.couple_id = new.couple_id
    and reminder.is_enabled
    and (
      (new.event_date - reminder.offset_days) + reminder.reminder_time
    ) at time zone couple_timezone <= clock_timestamp();

  return new;
end;
$$;

revoke execute on function
  private.disable_invalid_calendar_event_reminders()
from public, anon, authenticated;

drop trigger if exists disable_invalid_calendar_event_reminders
on public.couple_calendar_events;

create trigger disable_invalid_calendar_event_reminders
after update of event_date, repeat_rule
on public.couple_calendar_events
for each row
when (
  old.event_date is distinct from new.event_date
  or old.repeat_rule is distinct from new.repeat_rule
)
execute function private.disable_invalid_calendar_event_reminders();

update public.couple_calendar_event_reminders as reminder
set is_enabled = false
from public.couple_calendar_events as calendar_event,
  public.couples as couple
where calendar_event.id = reminder.event_id
  and calendar_event.couple_id = reminder.couple_id
  and couple.id = calendar_event.couple_id
  and calendar_event.repeat_rule = 'none'
  and reminder.is_enabled
  and (
    (calendar_event.event_date - reminder.offset_days)
      + reminder.reminder_time
  ) at time zone couple.timezone <= clock_timestamp();
