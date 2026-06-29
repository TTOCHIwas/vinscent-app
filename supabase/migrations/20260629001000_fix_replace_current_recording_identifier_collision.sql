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
  storage_object_visible boolean := false;
  visibility_attempt integer := 0;
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

  loop
    visibility_attempt := visibility_attempt + 1;

    select exists (
      select 1
      from storage.objects as so
      where so.bucket_id = 'couple-recordings'
        and so.name = requested_storage_path
    )
    into storage_object_visible;

    exit when storage_object_visible or visibility_attempt >= 10;

    perform pg_catalog.pg_sleep(0.1);
  end loop;

  if not storage_object_visible then
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
  on conflict on constraint couple_current_recordings_pkey
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
    select
      current_recording.couple_id,
      current_recording.slot_limit,
      current_recording.current_recording_id,
      current_recording.current_recording_path,
      current_recording.current_sender_user_id,
      current_recording.current_duration_ms,
      current_recording.current_recorded_at,
      current_recording.current_revision,
      current_recording.current_updated_at
    from public.get_current_couple_recording() as current_recording;
end;
$$;
