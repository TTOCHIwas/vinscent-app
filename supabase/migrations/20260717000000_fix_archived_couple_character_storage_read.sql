revoke execute on function private.is_current_user_character_storage_object(text, text)
  from public, anon;
grant execute on function private.is_current_user_character_storage_object(text, text)
  to authenticated;

drop policy if exists "couple_characters_storage_select_member"
  on storage.objects;

create policy "couple_characters_storage_select_member"
  on storage.objects
  for select
  to authenticated
  using (
    private.is_current_user_character_storage_object(bucket_id, name)
  );
