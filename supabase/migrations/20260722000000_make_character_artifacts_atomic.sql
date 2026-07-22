alter table public.storage_cleanup_requests
  drop constraint if exists storage_cleanup_requests_cleanup_reason_check;

alter table public.storage_cleanup_requests
  add constraint storage_cleanup_requests_cleanup_reason_check
    check (
      cleanup_reason in (
        'orphan_recording',
        'archive_recording',
        'archive_character',
        'orphan_character',
        'orphan_story_card',
        'archive_story_card',
        'orphan_recording_artwork',
        'archive_recording_artwork'
      )
    ) not valid;

alter table public.storage_cleanup_requests
  validate constraint storage_cleanup_requests_cleanup_reason_check;

alter table public.couple_characters
  add column artifact_revision uuid;

alter table public.couple_characters
  drop constraint if exists couple_characters_image_path_check,
  drop constraint if exists couple_characters_drawing_data_path_check;

alter table public.couple_characters
  add constraint couple_characters_artifact_paths_check
    check (
      (
        artifact_revision is null
        and image_path = couple_id::text || '/current.png'
        and drawing_data_path = couple_id::text || '/current.json'
      )
      or (
        artifact_revision is not null
        and image_path = couple_id::text
          || '/revisions/'
          || artifact_revision::text
          || '/preview.png'
        and drawing_data_path = couple_id::text
          || '/revisions/'
          || artifact_revision::text
          || '/drawing.json'
      )
    );

create or replace function private.is_valid_character_artifact_pair(
  target_couple_id uuid,
  target_image_path text,
  target_drawing_data_path text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select target_couple_id is not null
    and target_image_path is not null
    and target_drawing_data_path is not null
    and (
      (
        target_image_path = target_couple_id::text || '/current.png'
        and target_drawing_data_path = target_couple_id::text || '/current.json'
      )
      or (
        cardinality(regexp_split_to_array(target_image_path, '/')) = 4
        and split_part(target_image_path, '/', 1) = target_couple_id::text
        and split_part(target_image_path, '/', 2) = 'revisions'
        and split_part(target_image_path, '/', 3)
          ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and split_part(target_image_path, '/', 4) = 'preview.png'
        and target_drawing_data_path = target_couple_id::text
          || '/revisions/'
          || split_part(target_image_path, '/', 3)
          || '/drawing.json'
      )
    );
$$;

create or replace function private.is_current_user_character_storage_object(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select object_bucket_id = 'couple-characters'
    and exists (
      select 1
      from public.couples as c
      where (
          c.status = 'active'
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
        and (
          c.status <> 'active'
          or c.character_setup_status <> 'pending'
          or c.user_b_id = (select auth.uid())
        )
        and (
          object_name in (
            c.id::text || '/current.png',
            c.id::text || '/current.json'
          )
          or (
            cardinality(regexp_split_to_array(object_name, '/')) = 4
            and split_part(object_name, '/', 1) = c.id::text
            and split_part(object_name, '/', 2) = 'revisions'
            and split_part(object_name, '/', 3)
              ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            and split_part(object_name, '/', 4) in (
              'preview.png',
              'drawing.json'
            )
          )
        )
    );
$$;

create or replace function public.upsert_couple_character(
  character_image_path text,
  character_drawing_data_path text
)
returns table (
  couple_id uuid,
  image_path text,
  drawing_data_path text,
  updated_by uuid,
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
  previous_character public.couple_characters%rowtype;
  saved_character public.couple_characters%rowtype;
  requested_artifact_revision uuid;
  had_previous_character boolean;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if active_couple.character_setup_status = 'pending' then
    if active_couple.user_b_id <> current_user_id then
      perform private.raise_app_error('initial_setup_owner_required');
    end if;

    if active_couple.relationship_start_date is null then
      perform private.raise_app_error('relationship_date_required');
    end if;
  end if;

  if not private.is_valid_character_artifact_pair(
    active_couple.id,
    character_image_path,
    character_drawing_data_path
  ) then
    perform private.raise_app_error('invalid_character_path');
  end if;

  if character_image_path <> active_couple.id::text || '/current.png' then
    requested_artifact_revision := split_part(character_image_path, '/', 3)::uuid;
  end if;

  if not exists (
    select 1
    from storage.objects as so
    where so.bucket_id = 'couple-characters'
      and so.name = character_image_path
  ) or not exists (
    select 1
    from storage.objects as so
    where so.bucket_id = 'couple-characters'
      and so.name = character_drawing_data_path
  ) then
    perform private.raise_app_error('character_artifact_missing');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('couple_character_write'),
    hashtext(active_couple.id::text)
  );

  select *
  into previous_character
  from public.couple_characters as cc
  where cc.couple_id = active_couple.id
  for update;

  had_previous_character := found;

  if had_previous_character
    and previous_character.image_path = character_image_path
    and previous_character.drawing_data_path = character_drawing_data_path
  then
    return query
      select
        previous_character.couple_id,
        previous_character.image_path,
        previous_character.drawing_data_path,
        previous_character.updated_by,
        previous_character.created_at,
        previous_character.updated_at;
    return;
  end if;

  insert into public.couple_characters (
    couple_id,
    image_path,
    drawing_data_path,
    artifact_revision,
    updated_by
  )
  values (
    active_couple.id,
    character_image_path,
    character_drawing_data_path,
    requested_artifact_revision,
    current_user_id
  )
  on conflict on constraint couple_characters_pkey
  do update
    set
      image_path = excluded.image_path,
      drawing_data_path = excluded.drawing_data_path,
      artifact_revision = excluded.artifact_revision,
      updated_by = excluded.updated_by
  returning * into saved_character;

  update public.couples
  set character_setup_status = 'custom'
  where id = active_couple.id
    and character_setup_status <> 'custom';

  if had_previous_character then
    if previous_character.image_path <> saved_character.image_path then
      perform private.enqueue_storage_cleanup_request(
        'couple-characters',
        previous_character.image_path,
        'orphan_character',
        active_couple.id
      );
    end if;

    if previous_character.drawing_data_path <> saved_character.drawing_data_path then
      perform private.enqueue_storage_cleanup_request(
        'couple-characters',
        previous_character.drawing_data_path,
        'orphan_character',
        active_couple.id
      );
    end if;
  end if;

  return query
    select
      saved_character.couple_id,
      saved_character.image_path,
      saved_character.drawing_data_path,
      saved_character.updated_by,
      saved_character.created_at,
      saved_character.updated_at;
end;
$$;

create or replace function public.discard_uploaded_couple_character(
  requested_artifact_revision uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  target_path text;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_artifact_revision is null then
    perform private.raise_app_error('invalid_character_path');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if active_couple.character_setup_status = 'pending'
    and active_couple.user_b_id <> current_user_id
  then
    perform private.raise_app_error('initial_setup_owner_required');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('couple_character_write'),
    hashtext(active_couple.id::text)
  );

  if exists (
    select 1
    from public.couple_characters as cc
    where cc.couple_id = active_couple.id
      and cc.artifact_revision = requested_artifact_revision
  ) then
    return;
  end if;

  foreach target_path in array array[
    active_couple.id::text
      || '/revisions/'
      || requested_artifact_revision::text
      || '/preview.png',
    active_couple.id::text
      || '/revisions/'
      || requested_artifact_revision::text
      || '/drawing.json'
  ]
  loop
    if exists (
      select 1
      from storage.objects as so
      where so.bucket_id = 'couple-characters'
        and so.name = target_path
    ) then
      perform private.enqueue_storage_cleanup_request(
        'couple-characters',
        target_path,
        'orphan_character',
        active_couple.id
      );
    end if;
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

  for target_object_path in
    select so.name
    from storage.objects as so
    where so.bucket_id = 'couple-characters'
      and split_part(so.name, '/', 1) = target_couple_id::text
  loop
    perform private.enqueue_storage_cleanup_request(
      'couple-characters',
      target_object_path,
      'archive_character',
      target_couple_id
    );
  end loop;
end;
$$;

revoke execute on function private.is_valid_character_artifact_pair(uuid, text, text)
  from public, anon, authenticated;
revoke execute on function private.is_current_user_character_storage_object(text, text)
  from public, anon;
revoke execute on function private.delete_couple_character_storage_objects(uuid)
  from public, anon, authenticated;
revoke execute on function public.upsert_couple_character(text, text)
  from public, anon;
revoke execute on function public.discard_uploaded_couple_character(uuid)
  from public, anon;

grant execute on function private.is_current_user_character_storage_object(text, text)
  to authenticated;
grant execute on function public.upsert_couple_character(text, text)
  to authenticated;
grant execute on function public.discard_uploaded_couple_character(uuid)
  to authenticated;
