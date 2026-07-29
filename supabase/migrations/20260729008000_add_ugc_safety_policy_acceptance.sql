create table public.user_policy_acceptances (
  user_id uuid not null
    references auth.users(id) on delete cascade,
  policy_type text not null,
  policy_version text not null,
  accepted_at timestamptz not null default now(),

  primary key (user_id, policy_type, policy_version),
  constraint user_policy_acceptances_type_check
    check (policy_type in ('ugc_safety_policy')),
  constraint user_policy_acceptances_version_check
    check (char_length(btrim(policy_version)) between 1 and 80)
);

alter table public.user_policy_acceptances enable row level security;

create policy "user_policy_acceptances_select_own"
  on public.user_policy_acceptances
  for select
  using ((select auth.uid()) = user_id);

revoke all on table public.user_policy_acceptances
  from public, anon, authenticated;
grant select on table public.user_policy_acceptances to authenticated;
grant all on table public.user_policy_acceptances to service_role;

create or replace function private.current_ugc_safety_policy_version()
returns text
language sql
immutable
set search_path = ''
as $$
  select 'ugc-safety-v1'::text;
$$;

create or replace function private.has_current_ugc_safety_policy_acceptance(
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_policy_acceptances as acceptance
    where acceptance.user_id = target_user_id
      and acceptance.policy_type = 'ugc_safety_policy'
      and acceptance.policy_version =
        private.current_ugc_safety_policy_version()
  );
$$;

revoke all on function private.current_ugc_safety_policy_version()
  from public;
revoke all on function private.has_current_ugc_safety_policy_acceptance(uuid)
  from public;

create or replace function public.get_my_ugc_safety_policy_status()
returns table (
  policy_version text,
  is_accepted boolean,
  accepted_at timestamptz
)
language plpgsql
stable
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

  return query
  select
    current_policy_version,
    acceptance.accepted_at is not null,
    acceptance.accepted_at
  from (select 1) as singleton
  left join public.user_policy_acceptances as acceptance
    on acceptance.user_id = current_user_id
    and acceptance.policy_type = 'ugc_safety_policy'
    and acceptance.policy_version = current_policy_version;
end;
$$;

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
  on conflict (user_id, policy_type, policy_version)
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

revoke execute on function public.get_my_ugc_safety_policy_status()
  from public, anon;
grant execute on function public.get_my_ugc_safety_policy_status()
  to authenticated;

revoke execute on function public.accept_current_ugc_safety_policy(text)
  from public, anon;
grant execute on function public.accept_current_ugc_safety_policy(text)
  to authenticated;
