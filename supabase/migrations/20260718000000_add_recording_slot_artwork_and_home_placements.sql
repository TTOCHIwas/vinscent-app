insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'couple-recording-artworks',
  'couple-recording-artworks',
  false,
  262144,
  array[
    'image/webp',
    'application/gzip'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.storage_cleanup_requests
  drop constraint if exists storage_cleanup_requests_bucket_id_check,
  drop constraint if exists storage_cleanup_requests_cleanup_reason_check;

alter table public.storage_cleanup_requests
  add constraint storage_cleanup_requests_bucket_id_check
    check (
      bucket_id in (
        'couple-recordings',
        'couple-characters',
        'story-cards',
        'couple-recording-artworks'
      )
    ) not valid,
  add constraint storage_cleanup_requests_cleanup_reason_check
    check (
      cleanup_reason in (
        'orphan_recording',
        'archive_recording',
        'archive_character',
        'orphan_story_card',
        'archive_story_card',
        'orphan_recording_artwork',
        'archive_recording_artwork'
      )
    ) not valid;

alter table public.storage_cleanup_requests
  validate constraint storage_cleanup_requests_bucket_id_check;

alter table public.storage_cleanup_requests
  validate constraint storage_cleanup_requests_cleanup_reason_check;

alter table public.couple_recording_slots
  add column artwork_preview_path text,
  add column artwork_data_path text,
  add column artwork_revision integer;

alter table public.couple_recording_slots
  add constraint couple_recording_slots_id_couple_unique
    unique (id, couple_id),
  add constraint couple_recording_slots_artwork_state_check
    check (
      (
        artwork_preview_path is null
        and artwork_data_path is null
        and artwork_revision is null
      )
      or (
        artwork_preview_path is not null
        and artwork_data_path is not null
        and artwork_revision >= 1
      )
    );

create table public.couple_recording_slot_placements (
  slot_id uuid primary key,
  couple_id uuid not null,
  normalized_x double precision not null,
  normalized_y double precision not null,
  updated_by_user_id uuid references auth.users(id) on delete set null,
  revision integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint couple_recording_slot_placements_slot_couple_fk
    foreign key (slot_id, couple_id)
    references public.couple_recording_slots(id, couple_id)
    on delete cascade,
  constraint couple_recording_slot_placements_x_check
    check (normalized_x between 0 and 1),
  constraint couple_recording_slot_placements_y_check
    check (normalized_y between 0 and 1),
  constraint couple_recording_slot_placements_revision_check
    check (revision >= 1)
);

create index couple_recording_slot_placements_couple_idx
  on public.couple_recording_slot_placements (couple_id, updated_at desc);

alter table public.couple_recording_slot_placements enable row level security;

create trigger couple_recording_slot_placements_set_updated_at
  before update on public.couple_recording_slot_placements
  for each row
  execute function public.set_updated_at();

create policy "couple_recording_slot_placements_select_member"
  on public.couple_recording_slot_placements
  for select
  to authenticated
  using (
    private.is_readable_couple_member(couple_id, (select auth.uid()))
  );

create policy "couple_recording_artworks_storage_select_member"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'couple-recording-artworks'
    and exists (
      select 1
      from public.couple_recording_slots as crs
      where private.is_readable_couple_member(
          crs.couple_id,
          (select auth.uid())
        )
        and name ~ (
          '^'
          || crs.couple_id::text
          || '/slots/'
          || crs.id::text
          || '/artworks/[0-9a-f-]{36}/(preview[.]webp|drawing[.]json[.]gz)$'
        )
    )
  );

create policy "couple_recording_artworks_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'couple-recording-artworks'
    and exists (
      select 1
      from public.couple_recording_slots as crs
      where private.is_active_couple_member(
          crs.couple_id,
          (select auth.uid())
        )
        and name ~ (
          '^'
          || crs.couple_id::text
          || '/slots/'
          || crs.id::text
          || '/artworks/[0-9a-f-]{36}/(preview[.]webp|drawing[.]json[.]gz)$'
        )
    )
  );

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
  placement_revision integer
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
      crsp.revision
    from public.couple_recording_slots as crs
    join public.couple_recordings as cr
      on cr.id = crs.recording_id
    left join public.couple_recording_slot_placements as crsp
      on crsp.slot_id = crs.id
    where crs.couple_id = readable_couple.id
    order by crs.slot_index;
end;
$$;

create function public.save_couple_recording_slot_artwork(
  requested_slot_id uuid,
  requested_artifact_id uuid,
  expected_slot_revision integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  target_slot public.couple_recording_slots%rowtype;
  next_preview_path text;
  next_data_path text;
  previous_preview_path text;
  previous_data_path text;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_slot_id is null
    or requested_artifact_id is null
    or expected_slot_revision is null
    or expected_slot_revision < 1
  then
    perform private.raise_app_error('invalid_recording_artwork');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  select *
  into target_slot
  from public.couple_recording_slots as crs
  where crs.id = requested_slot_id
    and crs.couple_id = active_couple.id
  for update;

  if not found then
    perform private.raise_app_error('invalid_recording_slot');
  end if;

  if target_slot.revision <> expected_slot_revision then
    perform private.raise_app_error('recording_slot_conflict');
  end if;

  next_preview_path := active_couple.id::text
    || '/slots/' || target_slot.id::text
    || '/artworks/' || requested_artifact_id::text
    || '/preview.webp';
  next_data_path := active_couple.id::text
    || '/slots/' || target_slot.id::text
    || '/artworks/' || requested_artifact_id::text
    || '/drawing.json.gz';

  if not exists (
    select 1
    from storage.objects as so
    where so.bucket_id = 'couple-recording-artworks'
      and so.name = next_preview_path
  ) or not exists (
    select 1
    from storage.objects as so
    where so.bucket_id = 'couple-recording-artworks'
      and so.name = next_data_path
  ) then
    perform private.raise_app_error('recording_artwork_file_missing');
  end if;

  previous_preview_path := target_slot.artwork_preview_path;
  previous_data_path := target_slot.artwork_data_path;

  update public.couple_recording_slots
  set
    artwork_preview_path = next_preview_path,
    artwork_data_path = next_data_path,
    artwork_revision = coalesce(artwork_revision, 0) + 1,
    updated_by_user_id = current_user_id,
    revision = revision + 1
  where id = target_slot.id;

  if previous_preview_path is not null then
    perform private.enqueue_storage_cleanup_request(
      'couple-recording-artworks',
      previous_preview_path,
      'orphan_recording_artwork',
      active_couple.id
    );
  end if;

  if previous_data_path is not null then
    perform private.enqueue_storage_cleanup_request(
      'couple-recording-artworks',
      previous_data_path,
      'orphan_recording_artwork',
      active_couple.id
    );
  end if;
end;
$$;

create function public.discard_uploaded_couple_recording_slot_artwork(
  requested_slot_id uuid,
  requested_artifact_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  preview_path text;
  data_path text;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_slot_id is null or requested_artifact_id is null then
    perform private.raise_app_error('invalid_recording_artwork');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  preview_path := active_couple.id::text
    || '/slots/' || requested_slot_id::text
    || '/artworks/' || requested_artifact_id::text
    || '/preview.webp';
  data_path := active_couple.id::text
    || '/slots/' || requested_slot_id::text
    || '/artworks/' || requested_artifact_id::text
    || '/drawing.json.gz';

  if exists (
    select 1
    from public.couple_recording_slots as crs
    where crs.artwork_preview_path = preview_path
      or crs.artwork_data_path = data_path
  ) then
    return;
  end if;

  perform private.enqueue_storage_cleanup_request(
    'couple-recording-artworks',
    preview_path,
    'orphan_recording_artwork',
    active_couple.id
  );
  perform private.enqueue_storage_cleanup_request(
    'couple-recording-artworks',
    data_path,
    'orphan_recording_artwork',
    active_couple.id
  );
end;
$$;

create function public.upsert_couple_recording_slot_placement(
  requested_slot_id uuid,
  requested_normalized_x double precision,
  requested_normalized_y double precision,
  expected_placement_revision integer default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  target_slot public.couple_recording_slots%rowtype;
  existing_placement public.couple_recording_slot_placements%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_slot_id is null
    or requested_normalized_x is null
    or requested_normalized_y is null
    or requested_normalized_x::text in ('NaN', 'Infinity', '-Infinity')
    or requested_normalized_y::text in ('NaN', 'Infinity', '-Infinity')
    or requested_normalized_x < 0
    or requested_normalized_x > 1
    or requested_normalized_y < 0
    or requested_normalized_y > 1
  then
    perform private.raise_app_error('invalid_recording_placement');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  perform pg_advisory_xact_lock(
    hashtext('couple_recording_slot_placements'),
    hashtext(active_couple.id::text)
  );

  select *
  into target_slot
  from public.couple_recording_slots as crs
  where crs.id = requested_slot_id
    and crs.couple_id = active_couple.id
  for update;

  if not found then
    perform private.raise_app_error('invalid_recording_slot');
  end if;

  if target_slot.artwork_preview_path is null
    or target_slot.artwork_data_path is null
  then
    perform private.raise_app_error('recording_artwork_required');
  end if;

  select *
  into existing_placement
  from public.couple_recording_slot_placements as crsp
  where crsp.slot_id = target_slot.id
  for update;

  if found then
    if expected_placement_revision is null
      or existing_placement.revision <> expected_placement_revision
    then
      perform private.raise_app_error('recording_placement_conflict');
    end if;

    update public.couple_recording_slot_placements
    set
      normalized_x = requested_normalized_x,
      normalized_y = requested_normalized_y,
      updated_by_user_id = current_user_id,
      revision = revision + 1
    where slot_id = target_slot.id;
  else
    if expected_placement_revision is not null then
      perform private.raise_app_error('recording_placement_conflict');
    end if;

    if (
      select count(*)
      from public.couple_recording_slot_placements as crsp
      where crsp.couple_id = active_couple.id
    ) >= 4 then
      perform private.raise_app_error('recording_placement_limit_reached');
    end if;

    insert into public.couple_recording_slot_placements (
      slot_id,
      couple_id,
      normalized_x,
      normalized_y,
      updated_by_user_id
    )
    values (
      target_slot.id,
      active_couple.id,
      requested_normalized_x,
      requested_normalized_y,
      current_user_id
    );
  end if;
end;
$$;

create function public.delete_couple_recording_slot_placement(
  requested_slot_id uuid,
  expected_placement_revision integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  target_placement public.couple_recording_slot_placements%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_slot_id is null
    or expected_placement_revision is null
    or expected_placement_revision < 1
  then
    perform private.raise_app_error('recording_placement_conflict');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  select *
  into target_placement
  from public.couple_recording_slot_placements as crsp
  where crsp.slot_id = requested_slot_id
    and crsp.couple_id = active_couple.id
  for update;

  if not found then
    perform private.raise_app_error('invalid_recording_placement');
  end if;

  if target_placement.revision <> expected_placement_revision then
    perform private.raise_app_error('recording_placement_conflict');
  end if;

  update public.couple_recording_slot_placements
  set
    updated_by_user_id = current_user_id,
    revision = revision + 1
  where slot_id = target_placement.slot_id;

  delete from public.couple_recording_slot_placements
  where slot_id = target_placement.slot_id;
end;
$$;

create or replace function public.delete_couple_recording_slot(
  requested_slot_id uuid,
  expected_slot_revision integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  target_slot public.couple_recording_slots%rowtype;
  partner_user_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_slot_id is null then
    perform private.raise_app_error('invalid_recording_slot');
  end if;

  if expected_slot_revision is null or expected_slot_revision < 1 then
    perform private.raise_app_error('recording_slot_conflict');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  select *
  into target_slot
  from public.couple_recording_slots as crs
  where crs.id = requested_slot_id
    and crs.couple_id = active_couple.id
  for update;

  if not found then
    perform private.raise_app_error('invalid_recording_slot');
  end if;

  if target_slot.revision <> expected_slot_revision then
    perform private.raise_app_error('recording_slot_conflict');
  end if;

  partner_user_id := case
    when active_couple.user_a_id = current_user_id then active_couple.user_b_id
    when active_couple.user_b_id = current_user_id then active_couple.user_a_id
    else null
  end;

  if partner_user_id is not null then
    insert into public.recording_notification_events (
      couple_id,
      sender_user_id,
      receiver_user_id,
      event_type,
      recording_id,
      slot_index,
      slot_title
    )
    values (
      active_couple.id,
      current_user_id,
      partner_user_id,
      'slot_deleted',
      target_slot.recording_id,
      target_slot.slot_index,
      target_slot.title
    );
  end if;

  if target_slot.artwork_preview_path is not null then
    perform private.enqueue_storage_cleanup_request(
      'couple-recording-artworks',
      target_slot.artwork_preview_path,
      'orphan_recording_artwork',
      active_couple.id
    );
  end if;

  if target_slot.artwork_data_path is not null then
    perform private.enqueue_storage_cleanup_request(
      'couple-recording-artworks',
      target_slot.artwork_data_path,
      'orphan_recording_artwork',
      active_couple.id
    );
  end if;

  update public.couple_recording_slots
  set
    updated_by_user_id = current_user_id,
    revision = revision + 1
  where id = target_slot.id;

  delete from public.couple_recording_slots
  where id = target_slot.id;

  perform private.delete_couple_recording_if_orphaned(target_slot.recording_id);
end;
$$;

create or replace function private.delete_couple_recording_storage_objects(
  target_couple_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_storage_path text;
  target_slot public.couple_recording_slots%rowtype;
begin
  if target_couple_id is null then
    return;
  end if;

  for target_storage_path in
    select distinct cr.storage_path
    from public.couple_recordings as cr
    where cr.couple_id = target_couple_id
  loop
    perform private.enqueue_storage_cleanup_request(
      'couple-recordings',
      target_storage_path,
      'archive_recording',
      target_couple_id
    );
  end loop;

  for target_slot in
    select crs.*
    from public.couple_recording_slots as crs
    where crs.couple_id = target_couple_id
  loop
    if target_slot.artwork_preview_path is not null then
      perform private.enqueue_storage_cleanup_request(
        'couple-recording-artworks',
        target_slot.artwork_preview_path,
        'archive_recording_artwork',
        target_couple_id
      );
    end if;

    if target_slot.artwork_data_path is not null then
      perform private.enqueue_storage_cleanup_request(
        'couple-recording-artworks',
        target_slot.artwork_data_path,
        'archive_recording_artwork',
        target_couple_id
      );
    end if;
  end loop;
end;
$$;

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'couple_current_recordings'
  ) then
    alter publication supabase_realtime
      add table public.couple_current_recordings;
  end if;

  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'couple_recording_slot_settings'
  ) then
    alter publication supabase_realtime
      add table public.couple_recording_slot_settings;
  end if;

  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'couple_recording_slots'
  ) then
    alter publication supabase_realtime
      add table public.couple_recording_slots;
  end if;

  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'couple_recording_slot_placements'
  ) then
    alter publication supabase_realtime
      add table public.couple_recording_slot_placements;
  end if;
end;
$$;

revoke all on table public.couple_recording_slot_placements
  from public, anon;
revoke insert, update, delete on table public.couple_recording_slot_placements
  from authenticated;
grant select on table public.couple_recording_slot_placements
  to authenticated;

revoke execute on function public.list_couple_recording_slots()
  from public, anon;
revoke execute on function public.save_couple_recording_slot_artwork(uuid, uuid, integer)
  from public, anon;
revoke execute on function public.discard_uploaded_couple_recording_slot_artwork(uuid, uuid)
  from public, anon;
revoke execute on function public.upsert_couple_recording_slot_placement(uuid, double precision, double precision, integer)
  from public, anon;
revoke execute on function public.delete_couple_recording_slot_placement(uuid, integer)
  from public, anon;

grant execute on function public.list_couple_recording_slots()
  to authenticated;
grant execute on function public.save_couple_recording_slot_artwork(uuid, uuid, integer)
  to authenticated;
grant execute on function public.discard_uploaded_couple_recording_slot_artwork(uuid, uuid)
  to authenticated;
grant execute on function public.upsert_couple_recording_slot_placement(uuid, double precision, double precision, integer)
  to authenticated;
grant execute on function public.delete_couple_recording_slot_placement(uuid, integer)
  to authenticated;
