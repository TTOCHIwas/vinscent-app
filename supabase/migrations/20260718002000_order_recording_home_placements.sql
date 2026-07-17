alter table public.couple_recording_slot_placements
  add column z_index bigint;

with ranked_placements as (
  select
    slot_id,
    row_number() over (
      partition by couple_id
      order by updated_at, slot_id
    ) - 1 as z_index
  from public.couple_recording_slot_placements
)
update public.couple_recording_slot_placements as placements
set z_index = ranked_placements.z_index
from ranked_placements
where ranked_placements.slot_id = placements.slot_id;

alter table public.couple_recording_slot_placements
  alter column z_index set default 0,
  alter column z_index set not null,
  add constraint couple_recording_slot_placements_z_index_check
    check (z_index >= 0);

create unique index couple_recording_slot_placements_couple_z_index_idx
  on public.couple_recording_slot_placements (couple_id, z_index);

create function private.assign_recording_slot_placement_z_index()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_z_index bigint;
begin
  select coalesce(max(placement.z_index), -1) + 1
  into next_z_index
  from public.couple_recording_slot_placements as placement
  where placement.couple_id = new.couple_id
    and placement.slot_id <> new.slot_id;

  new.z_index := next_z_index;
  return new;
end;
$$;

create trigger couple_recording_slot_placements_assign_z_index
  before insert or update of normalized_x, normalized_y
  on public.couple_recording_slot_placements
  for each row
  execute function private.assign_recording_slot_placement_z_index();

drop function public.list_couple_recording_slots();

create function public.list_couple_recording_slots()
returns table (
  slot_id uuid,
  couple_id uuid,
  slot_index integer,
  title text,
  recording_id uuid,
  recording_path text,
  sender_user_id uuid,
  duration_ms integer,
  recorded_at timestamptz,
  slot_revision integer,
  created_by_user_id uuid,
  updated_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  artwork_preview_path text,
  artwork_data_path text,
  artwork_revision integer,
  placement_normalized_x double precision,
  placement_normalized_y double precision,
  placement_revision integer,
  placement_z_index bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  readable_couple public.couples%rowtype;
begin
  readable_couple := private.get_readable_couple_for_current_user();

  return query
    select
      crs.id,
      crs.couple_id,
      crs.slot_index,
      crs.title,
      cr.id,
      cr.storage_path,
      cr.sender_user_id,
      cr.duration_ms,
      cr.created_at,
      crs.revision,
      crs.created_by_user_id,
      crs.updated_by_user_id,
      crs.created_at,
      crs.updated_at,
      crs.artwork_preview_path,
      crs.artwork_data_path,
      crs.artwork_revision,
      crsp.normalized_x,
      crsp.normalized_y,
      crsp.revision,
      crsp.z_index
    from public.couple_recording_slots as crs
    join public.couple_recordings as cr
      on cr.id = crs.recording_id
    left join public.couple_recording_slot_placements as crsp
      on crsp.slot_id = crs.id
    where crs.couple_id = readable_couple.id
    order by crs.slot_index;
end;
$$;

revoke execute on function public.list_couple_recording_slots()
  from public, anon;

grant execute on function public.list_couple_recording_slots()
  to authenticated;

revoke execute on function private.assign_recording_slot_placement_z_index()
  from public, anon, authenticated;
