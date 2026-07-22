create or replace function private.is_current_user_readable_recording_storage_object(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select object_bucket_id = 'couple-recordings'
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
        and object_name like c.id::text || '/recordings/%'
    );
$$;

create or replace function private.is_current_user_writable_recording_storage_object(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select object_bucket_id = 'couple-recordings'
    and exists (
      select 1
      from public.couples as c
      where c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and object_name like c.id::text || '/recordings/%'
    );
$$;

create or replace function private.is_current_user_readable_recording_artwork_storage_object(
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
    and exists (
      select 1
      from public.couple_recording_slots as crs
      where private.is_readable_couple_member(
          crs.couple_id,
          (select auth.uid())
        )
        and object_name ~ (
          '^'
          || crs.couple_id::text
          || '/slots/'
          || crs.id::text
          || '/artworks/[0-9a-f-]{36}/(preview[.]webp|drawing[.]json[.]gz)$'
        )
    );
$$;

drop policy if exists "couple_characters_storage_insert_member"
  on storage.objects;
drop policy if exists "couple_characters_storage_update_member"
  on storage.objects;
drop policy if exists "couple_recordings_storage_select_member"
  on storage.objects;
drop policy if exists "couple_recordings_storage_insert_member"
  on storage.objects;
drop policy if exists "couple_recording_artworks_storage_select_member"
  on storage.objects;

create policy "couple_characters_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    private.is_current_user_character_storage_object(bucket_id, name)
  );

create policy "couple_characters_storage_update_member"
  on storage.objects
  for update
  to authenticated
  using (
    private.is_current_user_character_storage_object(bucket_id, name)
  )
  with check (
    private.is_current_user_character_storage_object(bucket_id, name)
  );

create policy "couple_recordings_storage_select_member"
  on storage.objects
  for select
  to authenticated
  using (
    private.is_current_user_readable_recording_storage_object(bucket_id, name)
  );

create policy "couple_recordings_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    private.is_current_user_writable_recording_storage_object(bucket_id, name)
  );

create policy "couple_recording_artworks_storage_select_member"
  on storage.objects
  for select
  to authenticated
  using (
    private.is_current_user_readable_recording_artwork_storage_object(
      bucket_id,
      name
    )
  );

revoke execute on function private.is_current_user_readable_recording_storage_object(text, text)
  from public, anon, authenticated;
revoke execute on function private.is_current_user_writable_recording_storage_object(text, text)
  from public, anon, authenticated;
revoke execute on function private.is_current_user_readable_recording_artwork_storage_object(text, text)
  from public, anon, authenticated;

grant execute on function private.is_current_user_readable_recording_storage_object(text, text)
  to authenticated;
grant execute on function private.is_current_user_writable_recording_storage_object(text, text)
  to authenticated;
grant execute on function private.is_current_user_readable_recording_artwork_storage_object(text, text)
  to authenticated;
