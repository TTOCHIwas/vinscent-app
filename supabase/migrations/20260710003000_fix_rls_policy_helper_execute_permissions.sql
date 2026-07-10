revoke execute on function private.is_readable_couple_member(uuid, uuid)
  from public, anon;
revoke execute on function private.is_current_user_character_storage_object(text, text)
  from public, anon;
revoke execute on function private.is_current_user_readable_story_card_storage_object(text, text)
  from public, anon;
revoke execute on function private.is_current_user_writable_story_card_storage_object(text, text)
  from public, anon;

grant execute on function private.is_readable_couple_member(uuid, uuid)
  to authenticated;
grant execute on function private.is_current_user_character_storage_object(text, text)
  to authenticated;
grant execute on function private.is_current_user_readable_story_card_storage_object(text, text)
  to authenticated;
grant execute on function private.is_current_user_writable_story_card_storage_object(text, text)
  to authenticated;

do $$
begin
  if not has_function_privilege(
    'authenticated',
    'private.is_readable_couple_member(uuid, uuid)',
    'execute'
  ) or not has_function_privilege(
    'authenticated',
    'private.is_current_user_character_storage_object(text, text)',
    'execute'
  ) or not has_function_privilege(
    'authenticated',
    'private.is_current_user_readable_story_card_storage_object(text, text)',
    'execute'
  ) or not has_function_privilege(
    'authenticated',
    'private.is_current_user_writable_story_card_storage_object(text, text)',
    'execute'
  ) then
    raise exception 'authenticated_rls_policy_helper_execute_required';
  end if;

  if has_function_privilege(
    'anon',
    'private.is_readable_couple_member(uuid, uuid)',
    'execute'
  ) or has_function_privilege(
    'anon',
    'private.is_current_user_character_storage_object(text, text)',
    'execute'
  ) or has_function_privilege(
    'anon',
    'private.is_current_user_readable_story_card_storage_object(text, text)',
    'execute'
  ) or has_function_privilege(
    'anon',
    'private.is_current_user_writable_story_card_storage_object(text, text)',
    'execute'
  ) then
    raise exception 'anon_rls_policy_helper_execute_forbidden';
  end if;
end;
$$;
