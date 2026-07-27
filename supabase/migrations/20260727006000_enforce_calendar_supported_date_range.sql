create or replace function private.enforce_supported_calendar_event_date()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.event_date > date '2100-12-31' then
    perform private.raise_app_error('invalid_calendar_event_date');
  end if;

  return new;
end;
$$;

drop trigger if exists couple_calendar_events_supported_date
  on public.couple_calendar_events;

create trigger couple_calendar_events_supported_date
  before insert or update of event_date
  on public.couple_calendar_events
  for each row
  execute function private.enforce_supported_calendar_event_date();

alter table public.couple_calendar_events
  drop constraint if exists couple_calendar_events_supported_date_check;

alter table public.couple_calendar_events
  add constraint couple_calendar_events_supported_date_check
  check (event_date <= date '2100-12-31');

revoke execute on function private.enforce_supported_calendar_event_date()
  from public, anon, authenticated;
