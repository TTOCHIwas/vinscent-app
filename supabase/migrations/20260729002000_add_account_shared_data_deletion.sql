create or replace function public.delete_account_shared_data(
  target_user_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_couple_count integer := 0;
  target_couple_id uuid;
begin
  if target_user_id is null then
    perform private.raise_app_error('account_user_required');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('couple_user'),
    hashtext(target_user_id::text)
  );

  for target_couple_id in
    select c.id
    from public.couples as c
    where c.user_a_id = target_user_id
      or c.user_b_id = target_user_id
    order by c.created_at
    for update
  loop
    perform private.delete_couple_shared_data(target_couple_id);
    deleted_couple_count := deleted_couple_count + 1;
  end loop;

  return deleted_couple_count;
end;
$$;

revoke execute on function public.delete_account_shared_data(uuid)
  from public, anon, authenticated;

grant execute on function public.delete_account_shared_data(uuid)
  to service_role;
