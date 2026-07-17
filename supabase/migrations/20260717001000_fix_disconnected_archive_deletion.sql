create or replace function private.enqueue_storage_cleanup_request(
  requested_bucket_id text,
  requested_object_path text,
  requested_cleanup_reason text,
  requested_source_couple_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_bucket_id text := btrim(requested_bucket_id);
  normalized_object_path text := btrim(requested_object_path);
  normalized_cleanup_reason text := btrim(requested_cleanup_reason);
  normalized_source_couple_id uuid;
begin
  if normalized_bucket_id is null or normalized_bucket_id = '' then
    return;
  end if;

  if normalized_object_path is null or normalized_object_path = '' then
    return;
  end if;

  if normalized_cleanup_reason is null or normalized_cleanup_reason = '' then
    return;
  end if;

  select c.id
  into normalized_source_couple_id
  from public.couples as c
  where c.id = requested_source_couple_id;

  insert into public.storage_cleanup_requests (
    bucket_id,
    object_path,
    cleanup_reason,
    source_couple_id
  )
  values (
    normalized_bucket_id,
    normalized_object_path,
    normalized_cleanup_reason,
    normalized_source_couple_id
  )
  on conflict do nothing;
end;
$$;

create or replace function private.enqueue_couple_story_card_storage_objects(
  target_couple_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_card public.story_loop_cards%rowtype;
begin
  if target_couple_id is null then
    return;
  end if;

  for target_card in
    select slc.*
    from public.story_loop_cards as slc
    where slc.couple_id = target_couple_id
  loop
    perform private.enqueue_story_card_artifact_cleanup(
      target_card.couple_id,
      target_card.preview_path,
      target_card.scene_data_path,
      target_card.background_image_path,
      'archive_story_card'
    );
  end loop;
end;
$$;

create or replace function private.enqueue_deleted_story_loop_card_artifacts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.enqueue_story_card_artifact_cleanup(
    null,
    old.preview_path,
    old.scene_data_path,
    old.background_image_path
  );

  return old;
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
  perform private.enqueue_couple_story_card_storage_objects(archived_couple.id);

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
    perform private.enqueue_couple_story_card_storage_objects(archived_couple_id);

    delete from public.couples
    where id = archived_couple_id;

    deleted_count := deleted_count + 1;
  end loop;

  return deleted_count;
end;
$$;

revoke execute on function private.enqueue_storage_cleanup_request(text, text, text, uuid)
  from public, anon, authenticated;
revoke execute on function private.enqueue_couple_story_card_storage_objects(uuid)
  from public, anon, authenticated;
revoke execute on function private.enqueue_deleted_story_loop_card_artifacts()
  from public, anon, authenticated;

revoke execute on function public.delete_disconnected_couple_archive_now()
  from public, anon;
revoke execute on function public.purge_expired_disconnected_couples(integer)
  from public, anon, authenticated;

grant execute on function public.delete_disconnected_couple_archive_now()
  to authenticated;
grant execute on function public.purge_expired_disconnected_couples(integer)
  to service_role;
