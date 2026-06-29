create or replace function public.open_next_couple_recording_slot()
returns table (
  couple_id uuid,
  slot_limit integer,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_couple public.couples%rowtype;
  slot_settings public.couple_recording_slot_settings%rowtype;
begin
  active_couple := private.get_active_couple_for_current_user();

  perform pg_advisory_xact_lock(
    hashtext('couple_recording_slot_settings'),
    hashtext(active_couple.id::text)
  );

  slot_settings := private.get_or_create_couple_recording_slot_settings(
    active_couple.id
  );

  if slot_settings.slot_limit >= 10 then
    perform private.raise_app_error('recording_slot_limit_reached');
  end if;

  update public.couple_recording_slot_settings as crss
  set slot_limit = crss.slot_limit + 1
  where crss.couple_id = active_couple.id
  returning *
  into slot_settings;

  return query
    select
      slot_settings.couple_id,
      slot_settings.slot_limit,
      slot_settings.updated_at;
end;
$$;
