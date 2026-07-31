create or replace function public.accept_current_ugc_safety_policy(
  requested_policy_version text
)
returns table (
  policy_version text,
  is_accepted boolean,
  accepted_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_policy_version text :=
    private.current_ugc_safety_policy_version();
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_policy_version is null
    or btrim(requested_policy_version) <> current_policy_version
  then
    perform private.raise_app_error('ugc_safety_policy_version_outdated');
  end if;

  insert into public.user_policy_acceptances (
    user_id,
    policy_type,
    policy_version
  )
  values (
    current_user_id,
    'ugc_safety_policy',
    current_policy_version
  )
  on conflict on constraint user_policy_acceptances_pkey
  do nothing;

  return query
  select
    current_policy_version,
    true,
    acceptance.accepted_at
  from public.user_policy_acceptances as acceptance
  where acceptance.user_id = current_user_id
    and acceptance.policy_type = 'ugc_safety_policy'
    and acceptance.policy_version = current_policy_version;
end;
$$;

revoke execute on function public.accept_current_ugc_safety_policy(text)
  from public, anon;
grant execute on function public.accept_current_ugc_safety_policy(text)
  to authenticated;
