insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'couple-recordings',
  'couple-recordings',
  false,
  5242880,
  array[
    'audio/mp4',
    'audio/m4a',
    'audio/x-m4a',
    'audio/aac'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table public.couple_recording_slot_settings (
  couple_id uuid primary key references public.couples(id) on delete cascade,
  slot_limit integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint couple_recording_slot_settings_slot_limit_check
    check (slot_limit between 0 and 10)
);

create table public.couple_recordings (
  id uuid primary key,
  couple_id uuid not null references public.couples(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  duration_ms integer not null,
  created_at timestamptz not null default now(),

  constraint couple_recordings_storage_path_check
    check (storage_path = couple_id::text || '/recordings/' || id::text || '.m4a'),
  constraint couple_recordings_duration_ms_check
    check (duration_ms between 1 and 15000)
);

create table public.couple_current_recordings (
  couple_id uuid primary key references public.couples(id) on delete cascade,
  recording_id uuid not null references public.couple_recordings(id) on delete cascade,
  updated_by_user_id uuid not null references auth.users(id) on delete cascade,
  revision integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint couple_current_recordings_revision_check
    check (revision >= 1)
);

create table public.couple_recording_slots (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  slot_index integer not null,
  title text not null,
  recording_id uuid not null references public.couple_recordings(id) on delete cascade,
  created_by_user_id uuid references auth.users(id) on delete set null,
  updated_by_user_id uuid references auth.users(id) on delete set null,
  revision integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint couple_recording_slots_couple_slot_unique
    unique (couple_id, slot_index),
  constraint couple_recording_slots_slot_index_check
    check (slot_index between 1 and 10),
  constraint couple_recording_slots_title_length_check
    check (char_length(btrim(title)) between 1 and 20),
  constraint couple_recording_slots_revision_check
    check (revision >= 1)
);

create table public.recording_notification_events (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  receiver_user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null,
  recording_id uuid references public.couple_recordings(id) on delete set null,
  slot_id uuid references public.couple_recording_slots(id) on delete set null,
  slot_index integer,
  slot_title text,
  created_at timestamptz not null default now(),

  constraint recording_notification_events_event_type_check
    check (
      event_type in (
        'current_recording_updated',
        'slot_saved',
        'slot_replaced',
        'slot_deleted'
      )
    ),
  constraint recording_notification_events_slot_index_check
    check (slot_index is null or slot_index between 1 and 10),
  constraint recording_notification_events_slot_title_length_check
    check (
      slot_title is null
      or char_length(btrim(slot_title)) between 1 and 20
    )
);

insert into public.couple_recording_slot_settings (couple_id)
select c.id
from public.couples as c
where c.status in ('pending', 'active', 'disconnected')
on conflict (couple_id) do nothing;

create index couple_recordings_couple_created_idx
  on public.couple_recordings (couple_id, created_at desc);

create index couple_recording_slots_couple_idx
  on public.couple_recording_slots (couple_id, slot_index);

create index recording_notification_events_receiver_created_idx
  on public.recording_notification_events (receiver_user_id, created_at desc);

alter table public.couple_recording_slot_settings enable row level security;
alter table public.couple_recordings enable row level security;
alter table public.couple_current_recordings enable row level security;
alter table public.couple_recording_slots enable row level security;
alter table public.recording_notification_events enable row level security;

create trigger couple_recording_slot_settings_set_updated_at
  before update on public.couple_recording_slot_settings
  for each row
  execute function public.set_updated_at();

create trigger couple_current_recordings_set_updated_at
  before update on public.couple_current_recordings
  for each row
  execute function public.set_updated_at();

create trigger couple_recording_slots_set_updated_at
  before update on public.couple_recording_slots
  for each row
  execute function public.set_updated_at();

create policy "couple_recording_slot_settings_select_member"
  on public.couple_recording_slot_settings
  for select
  to authenticated
  using (
    private.is_readable_couple_member(couple_id, (select auth.uid()))
  );

create policy "couple_recordings_select_member"
  on public.couple_recordings
  for select
  to authenticated
  using (
    private.is_readable_couple_member(couple_id, (select auth.uid()))
  );

create policy "couple_current_recordings_select_member"
  on public.couple_current_recordings
  for select
  to authenticated
  using (
    private.is_readable_couple_member(couple_id, (select auth.uid()))
  );

create policy "couple_recording_slots_select_member"
  on public.couple_recording_slots
  for select
  to authenticated
  using (
    private.is_readable_couple_member(couple_id, (select auth.uid()))
  );

create policy "couple_recordings_storage_select_member"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'couple-recordings'
    and exists (
      select 1
      from public.couples as c
      where (
          c.status in ('active', 'pending')
          or (
            c.status = 'disconnected'
            and c.archive_expires_at is not null
            and c.archive_expires_at > now()
          )
        )
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and name like c.id::text || '/recordings/%'
    )
  );

create policy "couple_recordings_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'couple-recordings'
    and exists (
      select 1
      from public.couples as c
      where c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and name like c.id::text || '/recordings/%'
    )
  );

create or replace function private.get_or_create_couple_recording_slot_settings(
  target_couple_id uuid
)
returns public.couple_recording_slot_settings
language plpgsql
security definer
set search_path = ''
as $$
declare
  settings_row public.couple_recording_slot_settings%rowtype;
begin
  insert into public.couple_recording_slot_settings (couple_id)
  values (target_couple_id)
  on conflict (couple_id) do nothing;

  select *
  into settings_row
  from public.couple_recording_slot_settings as crss
  where crss.couple_id = target_couple_id;

  return settings_row;
end;
$$;

create or replace function private.delete_couple_recording_if_orphaned(
  target_recording_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_recording public.couple_recordings%rowtype;
begin
  if target_recording_id is null then
    return;
  end if;

  select *
  into target_recording
  from public.couple_recordings as cr
  where cr.id = target_recording_id;

  if not found then
    return;
  end if;

  if exists (
    select 1
    from public.couple_current_recordings as ccr
    where ccr.recording_id = target_recording_id
  ) then
    return;
  end if;

  if exists (
    select 1
    from public.couple_recording_slots as crs
    where crs.recording_id = target_recording_id
  ) then
    return;
  end if;

  delete from storage.objects
  where bucket_id = 'couple-recordings'
    and name = target_recording.storage_path;

  delete from public.couple_recordings
  where id = target_recording_id;
end;
$$;

create or replace function private.delete_couple_recording_storage_objects(
  target_couple_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from storage.objects
  where bucket_id = 'couple-recordings'
    and name like target_couple_id::text || '/recordings/%';
$$;

create or replace function public.get_current_couple_recording()
returns table (
  couple_id uuid,
  slot_limit integer,
  current_recording_id uuid,
  current_recording_path text,
  current_sender_user_id uuid,
  current_duration_ms integer,
  current_recorded_at timestamptz,
  current_revision integer,
  current_updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  readable_couple public.couples%rowtype;
  slot_settings public.couple_recording_slot_settings%rowtype;
begin
  readable_couple := private.get_readable_couple_for_current_user();
  slot_settings := private.get_or_create_couple_recording_slot_settings(
    readable_couple.id
  );

  return query
    select
      readable_couple.id,
      slot_settings.slot_limit,
      cr.id,
      cr.storage_path,
      cr.sender_user_id,
      cr.duration_ms,
      cr.created_at,
      ccr.revision,
      ccr.updated_at
    from (values (1)) as seed(dummy)
    left join public.couple_current_recordings as ccr
      on ccr.couple_id = readable_couple.id
    left join public.couple_recordings as cr
      on cr.id = ccr.recording_id;
end;
$$;

create or replace function public.list_couple_recording_slots()
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
  updated_at timestamptz
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
      crs.updated_at
    from public.couple_recording_slots as crs
    join public.couple_recordings as cr
      on cr.id = crs.recording_id
    where crs.couple_id = readable_couple.id
    order by crs.slot_index;
end;
$$;

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

  update public.couple_recording_slot_settings
  set slot_limit = slot_limit + 1
  where public.couple_recording_slot_settings.couple_id = active_couple.id
  returning *
  into slot_settings;

  return query
    select
      slot_settings.couple_id,
      slot_settings.slot_limit,
      slot_settings.updated_at;
end;
$$;

create or replace function public.replace_current_couple_recording(
  requested_recording_id uuid,
  requested_storage_path text,
  requested_duration_ms integer
)
returns table (
  couple_id uuid,
  slot_limit integer,
  current_recording_id uuid,
  current_recording_path text,
  current_sender_user_id uuid,
  current_duration_ms integer,
  current_recorded_at timestamptz,
  current_revision integer,
  current_updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  slot_settings public.couple_recording_slot_settings%rowtype;
  previous_recording_id uuid;
  partner_user_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_recording_id is null then
    perform private.raise_app_error('invalid_recording_id');
  end if;

  if requested_duration_ms is null
    or requested_duration_ms < 1
    or requested_duration_ms > 15000
  then
    perform private.raise_app_error('invalid_recording_duration');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  slot_settings := private.get_or_create_couple_recording_slot_settings(
    active_couple.id
  );

  if requested_storage_path is distinct from
    active_couple.id::text || '/recordings/' || requested_recording_id::text || '.m4a'
  then
    perform private.raise_app_error('invalid_recording_path');
  end if;

  if not exists (
    select 1
    from storage.objects as so
    where so.bucket_id = 'couple-recordings'
      and so.name = requested_storage_path
  ) then
    perform private.raise_app_error('recording_file_missing');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('couple_current_recording'),
    hashtext(active_couple.id::text)
  );

  select ccr.recording_id
  into previous_recording_id
  from public.couple_current_recordings as ccr
  where ccr.couple_id = active_couple.id;

  insert into public.couple_recordings (
    id,
    couple_id,
    sender_user_id,
    storage_path,
    duration_ms
  )
  values (
    requested_recording_id,
    active_couple.id,
    current_user_id,
    requested_storage_path,
    requested_duration_ms
  );

  insert into public.couple_current_recordings (
    couple_id,
    recording_id,
    updated_by_user_id,
    revision
  )
  values (
    active_couple.id,
    requested_recording_id,
    current_user_id,
    1
  )
  on conflict (couple_id)
  do update
    set
      recording_id = excluded.recording_id,
      updated_by_user_id = excluded.updated_by_user_id,
      revision = public.couple_current_recordings.revision + 1;

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
      recording_id
    )
    values (
      active_couple.id,
      current_user_id,
      partner_user_id,
      'current_recording_updated',
      requested_recording_id
    );
  end if;

  perform private.delete_couple_recording_if_orphaned(previous_recording_id);

  return query
    select *
    from public.get_current_couple_recording();
end;
$$;

create or replace function public.save_current_couple_recording_to_slot(
  requested_slot_index integer,
  requested_title text,
  expected_slot_revision integer default null
)
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
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  slot_settings public.couple_recording_slot_settings%rowtype;
  current_recording public.couple_current_recordings%rowtype;
  existing_slot public.couple_recording_slots%rowtype;
  saved_slot public.couple_recording_slots%rowtype;
  target_recording public.couple_recordings%rowtype;
  previous_recording_id uuid;
  normalized_title text := btrim(requested_title);
  partner_user_id uuid;
  event_type text;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_slot_index is null
    or requested_slot_index < 1
    or requested_slot_index > 10
  then
    perform private.raise_app_error('invalid_recording_slot_index');
  end if;

  if normalized_title is null
    or normalized_title = ''
    or char_length(normalized_title) > 20
  then
    perform private.raise_app_error('invalid_recording_slot_title');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  slot_settings := private.get_or_create_couple_recording_slot_settings(
    active_couple.id
  );

  if requested_slot_index > slot_settings.slot_limit then
    perform private.raise_app_error('recording_slot_locked');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('couple_recording_slot'),
    hashtext(active_couple.id::text || ':' || requested_slot_index::text)
  );

  select *
  into current_recording
  from public.couple_current_recordings as ccr
  where ccr.couple_id = active_couple.id
  for update;

  if not found then
    perform private.raise_app_error('current_recording_required');
  end if;

  select *
  into target_recording
  from public.couple_recordings as cr
  where cr.id = current_recording.recording_id;

  if not found then
    perform private.raise_app_error('current_recording_required');
  end if;

  select *
  into existing_slot
  from public.couple_recording_slots as crs
  where crs.couple_id = active_couple.id
    and crs.slot_index = requested_slot_index
  for update;

  if found then
    if expected_slot_revision is null
      or existing_slot.revision <> expected_slot_revision
    then
      perform private.raise_app_error('recording_slot_conflict');
    end if;

    previous_recording_id := existing_slot.recording_id;
    event_type := 'slot_replaced';

    update public.couple_recording_slots
    set
      title = normalized_title,
      recording_id = target_recording.id,
      updated_by_user_id = current_user_id,
      revision = public.couple_recording_slots.revision + 1
    where public.couple_recording_slots.id = existing_slot.id
    returning *
    into saved_slot;
  else
    if expected_slot_revision is not null then
      perform private.raise_app_error('recording_slot_conflict');
    end if;

    event_type := 'slot_saved';

    insert into public.couple_recording_slots (
      couple_id,
      slot_index,
      title,
      recording_id,
      created_by_user_id,
      updated_by_user_id
    )
    values (
      active_couple.id,
      requested_slot_index,
      normalized_title,
      target_recording.id,
      current_user_id,
      current_user_id
    )
    returning *
    into saved_slot;
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
      slot_id,
      slot_index,
      slot_title
    )
    values (
      active_couple.id,
      current_user_id,
      partner_user_id,
      event_type,
      target_recording.id,
      saved_slot.id,
      saved_slot.slot_index,
      saved_slot.title
    );
  end if;

  perform private.delete_couple_recording_if_orphaned(previous_recording_id);

  return query
    select
      saved_slot.id,
      saved_slot.couple_id,
      saved_slot.slot_index,
      saved_slot.title,
      target_recording.id,
      target_recording.storage_path,
      target_recording.sender_user_id,
      target_recording.duration_ms,
      target_recording.created_at,
      saved_slot.revision,
      saved_slot.created_by_user_id,
      saved_slot.updated_by_user_id,
      saved_slot.created_at,
      saved_slot.updated_at;
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
  target_recording public.couple_recordings%rowtype;
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

  select *
  into target_recording
  from public.couple_recordings as cr
  where cr.id = target_slot.recording_id;

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

  delete from public.couple_recording_slots
  where id = target_slot.id;

  perform private.delete_couple_recording_if_orphaned(target_slot.recording_id);
end;
$$;

create or replace function public.delete_disconnected_couple_archive_now()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  archived_couple public.couples%rowtype;
begin
  archived_couple := private.get_archived_couple_for_current_user();

  perform private.delete_couple_character_storage_objects(archived_couple.id);
  perform private.delete_couple_recording_storage_objects(archived_couple.id);

  delete from public.couples
  where id = archived_couple.id;
end;
$$;

create or replace function public.purge_expired_disconnected_couples(
  batch_limit integer default 50
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer := 0;
  archived_couple_id uuid;
begin
  for archived_couple_id in
    select c.id
    from public.couples as c
    where c.status = 'disconnected'
      and c.archive_expires_at is not null
      and c.archive_expires_at <= now()
    order by c.archive_expires_at
    limit greatest(coalesce(batch_limit, 50), 1)
  loop
    perform private.delete_couple_character_storage_objects(archived_couple_id);
    perform private.delete_couple_recording_storage_objects(archived_couple_id);

    delete from public.couples
    where id = archived_couple_id;

    deleted_count := deleted_count + 1;
  end loop;

  return deleted_count;
end;
$$;

revoke execute on function private.get_or_create_couple_recording_slot_settings(uuid)
  from public, anon, authenticated;
revoke execute on function private.delete_couple_recording_if_orphaned(uuid)
  from public, anon, authenticated;
revoke execute on function private.delete_couple_recording_storage_objects(uuid)
  from public, anon, authenticated;

revoke execute on function public.get_current_couple_recording()
  from public, anon;
revoke execute on function public.list_couple_recording_slots()
  from public, anon;
revoke execute on function public.open_next_couple_recording_slot()
  from public, anon;
revoke execute on function public.replace_current_couple_recording(uuid, text, integer)
  from public, anon;
revoke execute on function public.save_current_couple_recording_to_slot(integer, text, integer)
  from public, anon;
revoke execute on function public.delete_couple_recording_slot(uuid, integer)
  from public, anon;

grant execute on function public.get_current_couple_recording()
  to authenticated;
grant execute on function public.list_couple_recording_slots()
  to authenticated;
grant execute on function public.open_next_couple_recording_slot()
  to authenticated;
grant execute on function public.replace_current_couple_recording(uuid, text, integer)
  to authenticated;
grant execute on function public.save_current_couple_recording_to_slot(integer, text, integer)
  to authenticated;
grant execute on function public.delete_couple_recording_slot(uuid, integer)
  to authenticated;
