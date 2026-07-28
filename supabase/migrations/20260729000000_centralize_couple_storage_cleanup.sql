create or replace function private.enqueue_all_couple_storage_objects(
  target_couple_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_object record;
begin
  if target_couple_id is null then
    return;
  end if;

  for target_object in
    select
      so.bucket_id,
      so.name as object_path,
      case so.bucket_id
        when 'couple-recordings' then 'archive_recording'
        when 'couple-characters' then 'archive_character'
        when 'story-cards' then 'archive_story_card'
        when 'couple-recording-artworks' then 'archive_recording_artwork'
        when 'couple-calendar-artworks' then 'archive_calendar_artwork'
      end as cleanup_reason
    from storage.objects as so
    where so.bucket_id in (
        'couple-recordings',
        'couple-characters',
        'story-cards',
        'couple-recording-artworks',
        'couple-calendar-artworks'
      )
      and split_part(so.name, '/', 1) = target_couple_id::text
  loop
    perform private.enqueue_storage_cleanup_request(
      target_object.bucket_id,
      target_object.object_path,
      target_object.cleanup_reason,
      target_couple_id
    );
  end loop;
end;
$$;

create or replace function public.delete_disconnected_couple_archive_now()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  archived_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select c.*
  into archived_couple
  from public.couples as c
  where c.status = 'disconnected'
    and c.archive_expires_at is not null
    and c.archive_expires_at > now()
    and (c.user_a_id = current_user_id or c.user_b_id = current_user_id)
  order by c.created_at desc
  limit 1
  for update;

  if not found then
    return;
  end if;

  perform private.enqueue_all_couple_storage_objects(archived_couple.id);

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
    for update skip locked
  loop
    perform private.enqueue_all_couple_storage_objects(archived_couple_id);

    delete from public.couples
    where id = archived_couple_id;

    deleted_count := deleted_count + 1;
  end loop;

  return deleted_count;
end;
$$;

revoke execute on function private.enqueue_all_couple_storage_objects(uuid)
  from public, anon, authenticated;

revoke execute on function public.delete_disconnected_couple_archive_now()
  from public, anon;
revoke execute on function public.purge_expired_disconnected_couples(integer)
  from public, anon, authenticated;

grant execute on function public.delete_disconnected_couple_archive_now()
  to authenticated;
grant execute on function public.purge_expired_disconnected_couples(integer)
  to service_role;
