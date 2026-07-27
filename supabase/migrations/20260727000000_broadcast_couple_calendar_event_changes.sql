create or replace function private.broadcast_couple_calendar_event_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  changed_couple_id uuid;
  changed_event_id uuid;
begin
  if tg_op = 'DELETE' then
    changed_couple_id := old.couple_id;
    changed_event_id := old.id;
  else
    changed_couple_id := new.couple_id;
    changed_event_id := new.id;
  end if;

  perform realtime.send(
    jsonb_build_object(
      'operation', lower(tg_op),
      'event_id', changed_event_id
    ),
    'calendar_event_changed',
    'couple-calendar-events:' || changed_couple_id::text,
    true
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke execute on function private.broadcast_couple_calendar_event_change()
from public, anon, authenticated;

drop trigger if exists broadcast_couple_calendar_event_change
on public.couple_calendar_events;

create trigger broadcast_couple_calendar_event_change
after insert or update or delete
on public.couple_calendar_events
for each row
execute function private.broadcast_couple_calendar_event_change();

drop policy if exists "couple_calendar_event_broadcast_select_member"
on realtime.messages;

create policy "couple_calendar_event_broadcast_select_member"
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and exists (
    select 1
    from public.couples as couple
    where (select realtime.topic()) =
      'couple-calendar-events:' || couple.id::text
      and private.is_readable_couple_member(
        couple.id,
        (select auth.uid())
      )
  )
);
