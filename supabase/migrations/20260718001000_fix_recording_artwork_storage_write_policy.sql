create or replace function private.is_current_user_writable_recording_artwork_storage_object(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select object_bucket_id = 'couple-recording-artworks'
    and cardinality(regexp_split_to_array(object_name, '/')) = 6
    and split_part(object_name, '/', 2) = 'slots'
    and split_part(object_name, '/', 3)
      ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and split_part(object_name, '/', 4) = 'artworks'
    and split_part(object_name, '/', 5)
      ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and split_part(object_name, '/', 6) in (
      'preview.webp',
      'drawing.json.gz'
    )
    and exists (
      select 1
      from public.couple_recording_slots as crs
      join public.couples as c
        on c.id = crs.couple_id
      where c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and split_part(object_name, '/', 1) = crs.couple_id::text
        and split_part(object_name, '/', 3) = crs.id::text
    );
$$;

drop policy if exists "couple_recording_artworks_storage_insert_member"
  on storage.objects;

create policy "couple_recording_artworks_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    private.is_current_user_writable_recording_artwork_storage_object(
      bucket_id,
      name
    )
  );

revoke execute on function private.is_current_user_writable_recording_artwork_storage_object(text, text)
  from public, anon, authenticated;

grant execute on function private.is_current_user_writable_recording_artwork_storage_object(text, text)
  to authenticated;

do $$
begin
  if not has_function_privilege(
    'authenticated',
    'private.is_current_user_writable_recording_artwork_storage_object(text, text)',
    'execute'
  ) then
    raise exception 'authenticated_recording_artwork_storage_helper_execute_required';
  end if;

  if has_function_privilege(
    'anon',
    'private.is_current_user_writable_recording_artwork_storage_object(text, text)',
    'execute'
  ) then
    raise exception 'anon_recording_artwork_storage_helper_execute_forbidden';
  end if;
end;
$$;
