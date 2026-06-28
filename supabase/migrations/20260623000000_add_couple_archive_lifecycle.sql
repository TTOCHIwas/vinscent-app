alter table public.couples
  add column if not exists disconnected_by_user_id uuid
    references auth.users(id) on delete set null,
  add column if not exists archive_expires_at timestamptz;

create index if not exists couples_archive_expires_at_idx
  on public.couples (archive_expires_at)
  where status = 'disconnected' and archive_expires_at is not null;

create table if not exists public.couple_reconnect_invites (
  couple_id uuid primary key references public.couples(id) on delete cascade,
  invite_code text not null unique,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.couple_reconnect_invites enable row level security;

create trigger couple_reconnect_invites_set_updated_at
  before update on public.couple_reconnect_invites
  for each row
  execute function public.set_updated_at();

create or replace function private.current_date_in_timezone(
  target_timezone text
)
returns date
language sql
stable
security definer
set search_path = ''
as $$
  select (now() at time zone coalesce(nullif(btrim(target_timezone), ''), 'Asia/Seoul'))::date;
$$;

create or replace function private.get_readable_couple_for_current_user()
returns public.couples
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  readable_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select *
  into readable_couple
  from public.couples
  where (
      status in ('pending', 'active')
      or (
        status = 'disconnected'
        and archive_expires_at is not null
        and archive_expires_at > now()
      )
    )
    and (
      user_a_id = current_user_id
      or user_b_id = current_user_id
    )
  order by created_at desc
  limit 1;

  if not found then
    perform private.raise_app_error('readable_couple_required');
  end if;

  return readable_couple;
end;
$$;

create or replace function private.is_readable_couple_member(
  target_couple_id uuid,
  target_user_id uuid
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.couples as c
    where c.id = target_couple_id
      and (
        c.status in ('pending', 'active')
        or (
          c.status = 'disconnected'
          and c.archive_expires_at is not null
          and c.archive_expires_at > now()
        )
      )
      and (
        c.user_a_id = target_user_id
        or c.user_b_id = target_user_id
      )
  );
$$;

create or replace function private.get_archived_couple_for_current_user()
returns public.couples
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

  select *
  into archived_couple
  from public.couples
  where status = 'disconnected'
    and archive_expires_at is not null
    and archive_expires_at > now()
    and (
      user_a_id = current_user_id
      or user_b_id = current_user_id
    )
  order by created_at desc
  limit 1;

  if not found then
    perform private.raise_app_error('archived_couple_required');
  end if;

  return archived_couple;
end;
$$;

create or replace function private.create_or_replace_reconnect_invite(
  target_couple_id uuid,
  owner_id uuid
)
returns public.couple_reconnect_invites
language plpgsql
security definer
set search_path = ''
as $$
declare
  generated_code text;
  reconnect_invite public.couple_reconnect_invites%rowtype;
  attempt integer;
begin
  for attempt in 1..20 loop
    generated_code := private.generate_invite_code();

    begin
      insert into public.couple_reconnect_invites (
        couple_id,
        invite_code,
        owner_user_id
      )
      values (
        target_couple_id,
        generated_code,
        owner_id
      )
      on conflict (couple_id)
      do update
        set
          invite_code = excluded.invite_code,
          owner_user_id = excluded.owner_user_id
      returning *
      into reconnect_invite;

      return reconnect_invite;
    exception
      when unique_violation then
        continue;
    end;
  end loop;

  perform private.raise_app_error('invite_code_generation_failed');
end;
$$;

create or replace function private.delete_couple_character_storage_objects(
  target_couple_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from storage.objects
  where bucket_id = 'couple-characters'
    and name in (
      target_couple_id::text || '/current.png',
      target_couple_id::text || '/current.json'
    );
$$;

create or replace function private.get_current_couple_context()
returns table (
  id uuid,
  invite_code text,
  user_a_id uuid,
  user_b_id uuid,
  relationship_start_date date,
  timezone text,
  status text,
  connected_at timestamptz,
  disconnected_at timestamptz,
  disconnected_by_user_id uuid,
  archive_expires_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  access_mode text,
  current_couple_date date
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  open_couple public.couples%rowtype;
  archived_couple public.couples%rowtype;
  reconnect_invite public.couple_reconnect_invites%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select c.*
  into open_couple
  from public.couples as c
  where c.status in ('pending', 'active')
    and (
      c.user_a_id = current_user_id
      or c.user_b_id = current_user_id
    )
  order by c.created_at desc
  limit 1;

  if found then
    return query
      select
        open_couple.id,
        open_couple.invite_code,
        open_couple.user_a_id,
        open_couple.user_b_id,
        open_couple.relationship_start_date,
        open_couple.timezone,
        open_couple.status,
        open_couple.connected_at,
        open_couple.disconnected_at,
        open_couple.disconnected_by_user_id,
        open_couple.archive_expires_at,
        open_couple.created_at,
        open_couple.updated_at,
        case
          when open_couple.status = 'pending' then 'pending'::text
          else 'active'::text
        end,
        private.current_date_in_timezone(open_couple.timezone) as current_couple_date;

    return;
  end if;

  select c.*
  into archived_couple
  from public.couples as c
  where c.status = 'disconnected'
    and c.archive_expires_at is not null
    and c.archive_expires_at > now()
    and (
      c.user_a_id = current_user_id
      or c.user_b_id = current_user_id
    )
  order by c.created_at desc
  limit 1;

  if not found then
    return;
  end if;

  select *
  into reconnect_invite
  from public.couple_reconnect_invites
  where couple_id = archived_couple.id
    and owner_user_id = current_user_id;

  return query
    select
      archived_couple.id,
      coalesce(reconnect_invite.invite_code, archived_couple.invite_code),
      archived_couple.user_a_id,
      archived_couple.user_b_id,
      archived_couple.relationship_start_date,
      archived_couple.timezone,
      archived_couple.status,
      archived_couple.connected_at,
      archived_couple.disconnected_at,
      archived_couple.disconnected_by_user_id,
      archived_couple.archive_expires_at,
      archived_couple.created_at,
      archived_couple.updated_at,
      case
        when reconnect_invite.couple_id is not null then 'pending'::text
        else 'archived_read_only'::text
      end,
      private.current_date_in_timezone(archived_couple.timezone) as current_couple_date;
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
  archived_couple public.couples%rowtype;
  reconnect_invite public.couple_reconnect_invites%rowtype;
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

  select *
  into archived_couple
  from public.couples
  where status = 'disconnected'
    and archive_expires_at is not null
    and archive_expires_at > now()
    and (
      user_a_id = current_user_id
      or user_b_id = current_user_id
    )
  order by created_at desc
  limit 1
  for update;

  if found then
    reconnect_invite := private.create_or_replace_reconnect_invite(
      archived_couple.id,
      current_user_id
    );

    update public.couples
    set invite_code = reconnect_invite.invite_code
    where public.couples.id = archived_couple.id
    returning * into archived_couple;

    return archived_couple;
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
  reconnect_invite public.couple_reconnect_invites%rowtype;
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

  if exists (
    select 1
    from public.couples
    where status = 'disconnected'
      and archive_expires_at is not null
      and archive_expires_at > now()
      and (
        user_a_id = current_user_id
        or user_b_id = current_user_id
      )
  ) then
    select cri.*
    into reconnect_invite
    from public.couple_reconnect_invites as cri
    where cri.invite_code = normalized_code
    for update;

    if not found then
      perform private.raise_app_error('archived_couple_exists');
    end if;

    select *
    into target_couple
    from public.couples
    where id = reconnect_invite.couple_id
    for update;

    if not found
      or target_couple.status <> 'disconnected'
      or target_couple.archive_expires_at is null
      or target_couple.archive_expires_at <= now()
    then
      perform private.raise_app_error('invite_not_pending');
    end if;

    if reconnect_invite.owner_user_id = current_user_id then
      perform private.raise_app_error('cannot_join_own_invite');
    end if;

    if current_user_id not in (target_couple.user_a_id, target_couple.user_b_id) then
      perform private.raise_app_error('archived_couple_exists');
    end if;

    update public.couples
    set
      status = 'active',
      connected_at = now(),
      disconnected_at = null,
      disconnected_by_user_id = null,
      archive_expires_at = null
    where id = target_couple.id
    returning * into target_couple;

    delete from public.couple_reconnect_invites
    where couple_id = target_couple.id;

    return target_couple;
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
  target_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('couple_user'),
    hashtext(current_user_id::text)
  );

  select *
  into target_couple
  from public.couples
  where user_a_id = current_user_id
    and status = 'pending'
  order by created_at desc
  limit 1
  for update;

  if found then
    update public.couples
    set status = 'cancelled'
    where id = target_couple.id;

    return;
  end if;

  delete from public.couple_reconnect_invites
  where owner_user_id = current_user_id;
end;
$$;

create or replace function public.disconnect_couple()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  perform pg_advisory_xact_lock(
    hashtext('couple_disconnect'),
    hashtext(active_couple.id::text)
  );

  update public.couples
  set
    status = 'disconnected',
    disconnected_at = now(),
    disconnected_by_user_id = current_user_id,
    archive_expires_at = now() + interval '30 days'
  where id = active_couple.id;

  delete from public.couple_reconnect_invites
  where couple_id = active_couple.id;
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

    delete from public.couples
    where id = archived_couple_id;

    deleted_count := deleted_count + 1;
  end loop;

  return deleted_count;
end;
$$;

create or replace function public.get_current_couple_context()
returns table (
  id uuid,
  invite_code text,
  user_a_id uuid,
  user_b_id uuid,
  relationship_start_date date,
  timezone text,
  status text,
  connected_at timestamptz,
  disconnected_at timestamptz,
  disconnected_by_user_id uuid,
  archive_expires_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  access_mode text,
  current_couple_date date
)
language sql
security definer
set search_path = ''
as $$
  select *
  from private.get_current_couple_context();
$$;

revoke execute on function private.current_date_in_timezone(text)
  from public, anon, authenticated;
revoke execute on function private.get_readable_couple_for_current_user()
  from public, anon, authenticated;
revoke execute on function private.is_readable_couple_member(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function private.get_archived_couple_for_current_user()
  from public, anon, authenticated;
revoke execute on function private.create_or_replace_reconnect_invite(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function private.delete_couple_character_storage_objects(uuid)
  from public, anon, authenticated;
revoke execute on function private.get_current_couple_context()
  from public, anon, authenticated;

revoke execute on function public.disconnect_couple()
  from public, anon;
revoke execute on function public.delete_disconnected_couple_archive_now()
  from public, anon;
revoke execute on function public.purge_expired_disconnected_couples(integer)
  from public, anon, authenticated;
revoke execute on function public.get_current_couple_context()
  from public, anon;

grant execute on function public.disconnect_couple()
  to authenticated;
grant execute on function public.delete_disconnected_couple_archive_now()
  to authenticated;
grant execute on function public.get_current_couple_context()
  to authenticated;
grant execute on function public.purge_expired_disconnected_couples(integer)
  to service_role;
