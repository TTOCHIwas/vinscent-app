create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;

create table public.couples (
  id uuid primary key default gen_random_uuid(),
  invite_code text not null unique,
  user_a_id uuid not null references auth.users(id) on delete cascade,
  user_b_id uuid references auth.users(id) on delete set null,
  relationship_start_date date,
  timezone text not null default 'Asia/Seoul',
  status text not null default 'pending',
  connected_at timestamptz,
  disconnected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint couples_status_check
    check (status in ('pending', 'active', 'cancelled', 'disconnected')),
  constraint couples_distinct_users
    check (user_b_id is null or user_a_id <> user_b_id),
  constraint couples_active_requires_partner
    check (status <> 'active' or user_b_id is not null),
  constraint couples_relationship_start_date_not_future
    check (
      relationship_start_date is null
      or relationship_start_date <= current_date
    )
);

create unique index couples_user_a_open_unique
  on public.couples (user_a_id)
  where status in ('pending', 'active');

create unique index couples_user_b_active_unique
  on public.couples (user_b_id)
  where status = 'active' and user_b_id is not null;

create index couples_user_b_id_idx
  on public.couples (user_b_id)
  where user_b_id is not null;

create index couples_status_idx
  on public.couples (status);

alter table public.couples enable row level security;

create policy "couples_select_member"
  on public.couples
  for select
  to authenticated
  using (
    (select auth.uid()) = user_a_id
    or (select auth.uid()) = user_b_id
  );

create trigger couples_set_updated_at
  before update on public.couples
  for each row
  execute function public.set_updated_at();

create or replace function private.raise_app_error(error_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = error_code;
end;
$$;

create or replace function private.ensure_profile_exists(user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.profiles
    where id = user_id
  ) then
    perform private.raise_app_error('profile_required');
  end if;
end;
$$;

create or replace function private.has_open_couple(user_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.couples
    where status in ('pending', 'active')
      and (user_a_id = user_id or user_b_id = user_id)
  );
$$;

create or replace function private.generate_invite_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text := '';
  counter integer;
begin
  for counter in 1..6 loop
    code := code || substr(
      alphabet,
      1 + floor(random() * length(alphabet))::integer,
      1
    );
  end loop;

  return code;
end;
$$;

create or replace function private.create_couple_invite()
returns public.couples
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  generated_code text;
  created_couple public.couples%rowtype;
  attempt integer;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  perform private.ensure_profile_exists(current_user_id);
  perform pg_advisory_xact_lock(
    hashtext('couple_user'),
    hashtext(current_user_id::text)
  );

  if private.has_open_couple(current_user_id) then
    perform private.raise_app_error('couple_already_exists');
  end if;

  for attempt in 1..20 loop
    generated_code := private.generate_invite_code();

    begin
      insert into public.couples (invite_code, user_a_id)
      values (generated_code, current_user_id)
      returning * into created_couple;

      return created_couple;
    exception
      when unique_violation then
        continue;
    end;
  end loop;

  perform private.raise_app_error('invite_code_generation_failed');
end;
$$;

create or replace function private.join_couple_by_code(invite_code text)
returns public.couples
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_code text := upper(btrim(invite_code));
  target_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  perform private.ensure_profile_exists(current_user_id);
  perform pg_advisory_xact_lock(
    hashtext('couple_user'),
    hashtext(current_user_id::text)
  );

  if normalized_code is null or normalized_code !~ '^[A-HJ-NP-Z2-9]{6}$' then
    perform private.raise_app_error('invalid_invite_code');
  end if;

  if private.has_open_couple(current_user_id) then
    perform private.raise_app_error('couple_already_exists');
  end if;

  select *
  into target_couple
  from public.couples
  where public.couples.invite_code = normalized_code
  for update;

  if not found then
    perform private.raise_app_error('invite_not_found');
  end if;

  if target_couple.status <> 'pending' then
    perform private.raise_app_error('invite_not_pending');
  end if;

  if target_couple.user_a_id = current_user_id then
    perform private.raise_app_error('cannot_join_own_invite');
  end if;

  update public.couples
  set
    user_b_id = current_user_id,
    status = 'active',
    connected_at = now()
  where id = target_couple.id
  returning * into target_couple;

  return target_couple;
end;
$$;

create or replace function private.cancel_couple_invite()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('couple_user'),
    hashtext(current_user_id::text)
  );

  update public.couples
  set status = 'cancelled'
  where user_a_id = current_user_id
    and status = 'pending';
end;
$$;

create or replace function private.update_relationship_start_date(
  start_date date
)
returns public.couples
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  target_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if start_date is null or start_date > current_date then
    perform private.raise_app_error('relationship_date_in_future');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('couple_user'),
    hashtext(current_user_id::text)
  );

  select *
  into target_couple
  from public.couples
  where status = 'active'
    and (user_a_id = current_user_id or user_b_id = current_user_id)
  for update;

  if not found then
    perform private.raise_app_error('active_couple_required');
  end if;

  update public.couples
  set relationship_start_date = start_date
  where id = target_couple.id
  returning * into target_couple;

  return target_couple;
end;
$$;

create or replace function public.create_couple_invite()
returns public.couples
language sql
security definer
set search_path = ''
as $$
  select * from private.create_couple_invite();
$$;

create or replace function public.join_couple_by_code(invite_code text)
returns public.couples
language sql
security definer
set search_path = ''
as $$
  select * from private.join_couple_by_code(invite_code);
$$;

create or replace function public.cancel_couple_invite()
returns void
language sql
security definer
set search_path = ''
as $$
  select private.cancel_couple_invite();
$$;

create or replace function public.update_relationship_start_date(
  start_date date
)
returns public.couples
language sql
security definer
set search_path = ''
as $$
  select * from private.update_relationship_start_date(start_date);
$$;

revoke execute on function private.raise_app_error(text)
  from public, anon, authenticated;
revoke execute on function private.ensure_profile_exists(uuid)
  from public, anon, authenticated;
revoke execute on function private.has_open_couple(uuid)
  from public, anon, authenticated;
revoke execute on function private.generate_invite_code()
  from public, anon, authenticated;
revoke execute on function private.create_couple_invite()
  from public, anon, authenticated;
revoke execute on function private.join_couple_by_code(text)
  from public, anon, authenticated;
revoke execute on function private.cancel_couple_invite()
  from public, anon, authenticated;
revoke execute on function private.update_relationship_start_date(date)
  from public, anon, authenticated;

revoke execute on function public.create_couple_invite()
  from public, anon;
revoke execute on function public.join_couple_by_code(text)
  from public, anon;
revoke execute on function public.cancel_couple_invite()
  from public, anon;
revoke execute on function public.update_relationship_start_date(date)
  from public, anon;

grant execute on function public.create_couple_invite()
  to authenticated;
grant execute on function public.join_couple_by_code(text)
  to authenticated;
grant execute on function public.cancel_couple_invite()
  to authenticated;
grant execute on function public.update_relationship_start_date(date)
  to authenticated;
