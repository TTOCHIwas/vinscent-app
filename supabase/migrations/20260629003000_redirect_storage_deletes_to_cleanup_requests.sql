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

  perform private.enqueue_storage_cleanup_request(
    'couple-recordings',
    target_recording.storage_path,
    'orphan_recording',
    target_recording.couple_id
  );

  delete from public.couple_recordings
  where id = target_recording_id;
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
end;
$$;

create or replace function private.delete_couple_character_storage_objects(
  target_couple_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_object_path text;
begin
  if target_couple_id is null then
    return;
  end if;

  foreach target_object_path in array array[
    target_couple_id::text || '/current.png',
    target_couple_id::text || '/current.json'
  ]
  loop
    if exists (
      select 1
      from storage.objects as so
      where so.bucket_id = 'couple-characters'
        and so.name = target_object_path
    ) then
      perform private.enqueue_storage_cleanup_request(
        'couple-characters',
        target_object_path,
        'archive_character',
        target_couple_id
      );
    end if;
  end loop;
end;
$$;

create or replace function public.discard_uploaded_couple_recording(
  requested_recording_id uuid,
  requested_storage_path text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_recording_id is null then
    perform private.raise_app_error('invalid_recording_id');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if requested_storage_path is distinct from
    active_couple.id::text || '/recordings/' || requested_recording_id::text || '.m4a'
  then
    perform private.raise_app_error('invalid_recording_path');
  end if;

  if exists (
    select 1
    from public.couple_recordings as cr
    where cr.id = requested_recording_id
      or cr.storage_path = requested_storage_path
  ) then
    return;
  end if;

  perform private.enqueue_storage_cleanup_request(
    'couple-recordings',
    requested_storage_path,
    'orphan_recording',
    active_couple.id
  );
end;
$$;
