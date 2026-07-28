alter table public.couples
  add column disconnect_reason text;

alter table public.couples
  add constraint couples_disconnect_reason_check
  check (
    disconnect_reason is null
    or (
      status = 'disconnected'
      and disconnect_reason in ('manual', 'user_block')
    )
  );

create table public.user_blocks (
  blocker_user_id uuid not null
    references auth.users(id) on delete cascade,
  blocked_user_id uuid not null
    references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),

  primary key (blocker_user_id, blocked_user_id),
  constraint user_blocks_distinct_users
    check (blocker_user_id <> blocked_user_id)
);

create index user_blocks_blocked_user_idx
  on public.user_blocks (blocked_user_id, created_at desc);

alter table public.user_blocks enable row level security;

revoke all on table public.user_blocks
  from public, anon, authenticated;
grant all on table public.user_blocks
  to service_role;

create table public.user_safety_states (
  user_id uuid primary key
    references auth.users(id) on delete cascade,
  revision bigint not null default 1
    check (revision > 0),
  updated_at timestamptz not null default now()
);

alter table public.user_safety_states enable row level security;

create policy "user_safety_states_select_own"
  on public.user_safety_states
  for select
  to authenticated
  using (user_id = (select auth.uid()));

revoke all on table public.user_safety_states
  from public, anon, authenticated;
grant select on table public.user_safety_states
  to authenticated;
grant all on table public.user_safety_states
  to service_role;

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'user_safety_states'
  ) then
    alter publication supabase_realtime
      add table public.user_safety_states;
  end if;
end;
$$;

create or replace function private.bump_user_safety_states(
  target_user_ids uuid[]
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.user_safety_states (user_id, revision, updated_at)
  select distinct requested_user_id, 1, now()
  from unnest(target_user_ids) as requested(requested_user_id)
  where requested.requested_user_id is not null
  on conflict (user_id)
  do update
    set
      revision = public.user_safety_states.revision + 1,
      updated_at = now();
$$;

create or replace function private.is_blocked_pair(
  first_user_id uuid,
  second_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select first_user_id is not null
    and second_user_id is not null
    and exists (
      select 1
      from public.user_blocks as ub
      where (
          ub.blocker_user_id = first_user_id
          and ub.blocked_user_id = second_user_id
        )
        or (
          ub.blocker_user_id = second_user_id
          and ub.blocked_user_id = first_user_id
        )
    );
$$;

create or replace function private.is_readable_couple_member(
  target_couple_id uuid,
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
    from public.couples as c
    where c.id = target_couple_id
      and (
        c.status in ('pending', 'active')
        or (
          c.status = 'disconnected'
          and c.disconnect_reason is distinct from 'user_block'
          and c.archive_expires_at is not null
          and c.archive_expires_at > now()
        )
      )
      and (
        c.user_a_id = target_user_id
        or c.user_b_id = target_user_id
      )
      and (
        c.user_b_id is null
        or not private.is_blocked_pair(c.user_a_id, c.user_b_id)
      )
  );
$$;

create or replace function private.can_view_couple_context(
  target_couple_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_readable_couple_member(
      target_couple_id,
      target_user_id
    )
    or exists (
      select 1
      from public.couple_reconnect_invites as cri
      join public.couples as c
        on c.id = cri.couple_id
      where cri.couple_id = target_couple_id
        and cri.owner_user_id = target_user_id
        and c.status = 'disconnected'
        and c.disconnect_reason = 'user_block'
        and c.archive_expires_at is not null
        and c.archive_expires_at > now()
        and not private.is_blocked_pair(c.user_a_id, c.user_b_id)
    );
$$;

drop policy if exists "couples_select_member"
  on public.couples;

create policy "couples_select_member"
  on public.couples
  for select
  to authenticated
  using (
    private.can_view_couple_context(id, (select auth.uid()))
  );

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

  select c.*
  into readable_couple
  from public.couples as c
  where private.is_readable_couple_member(c.id, current_user_id)
  order by c.created_at desc
  limit 1;

  if not found then
    perform private.raise_app_error('readable_couple_required');
  end if;

  return readable_couple;
end;
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

  select c.*
  into archived_couple
  from public.couples as c
  where c.status = 'disconnected'
    and c.disconnect_reason is distinct from 'user_block'
    and c.archive_expires_at is not null
    and c.archive_expires_at > now()
    and (
      c.user_a_id = current_user_id
      or c.user_b_id = current_user_id
    )
  order by c.created_at desc
  limit 1;

  if not found then
    perform private.raise_app_error('archived_couple_required');
  end if;

  return archived_couple;
end;
$$;

create or replace function private.get_current_couple_context()
returns table (
  id uuid,
  invite_code text,
  user_a_id uuid,
  user_b_id uuid,
  relationship_start_date date,
  character_setup_status text,
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
    and (
      c.user_b_id is null
      or not private.is_blocked_pair(c.user_a_id, c.user_b_id)
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
        open_couple.character_setup_status,
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
        private.current_date_in_timezone(open_couple.timezone);

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
    and (
      c.disconnect_reason is distinct from 'user_block'
      or exists (
        select 1
        from public.couple_reconnect_invites as owned_invite
        where owned_invite.couple_id = c.id
          and owned_invite.owner_user_id = current_user_id
      )
    )
  order by c.created_at desc
  limit 1;

  if not found then
    return;
  end if;

  select cri.*
  into reconnect_invite
  from public.couple_reconnect_invites as cri
  where cri.couple_id = archived_couple.id
    and cri.owner_user_id = current_user_id;

  return query
    select
      archived_couple.id,
      coalesce(reconnect_invite.invite_code, archived_couple.invite_code),
      archived_couple.user_a_id,
      archived_couple.user_b_id,
      archived_couple.relationship_start_date,
      archived_couple.character_setup_status,
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
      private.current_date_in_timezone(archived_couple.timezone);
end;
$$;

create or replace function private.prevent_blocked_couple_activation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'active'
    and new.user_b_id is not null
    and private.is_blocked_pair(new.user_a_id, new.user_b_id)
  then
    perform private.raise_app_error('user_blocked');
  end if;

  return new;
end;
$$;

drop trigger if exists couples_prevent_blocked_activation
  on public.couples;

create trigger couples_prevent_blocked_activation
  before insert or update of status, user_a_id, user_b_id
  on public.couples
  for each row
  execute function private.prevent_blocked_couple_activation();

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

  select c.*
  into archived_couple
  from public.couples as c
  where c.status = 'disconnected'
    and c.disconnect_reason is distinct from 'user_block'
    and c.archive_expires_at is not null
    and c.archive_expires_at > now()
    and (
      c.user_a_id = current_user_id
      or c.user_b_id = current_user_id
    )
  order by c.created_at desc
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

  select cri.*
  into reconnect_invite
  from public.couple_reconnect_invites as cri
  where cri.invite_code = normalized_code
  for update;

  if found then
    select c.*
    into target_couple
    from public.couples as c
    where c.id = reconnect_invite.couple_id
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

    if current_user_id not in (
      target_couple.user_a_id,
      target_couple.user_b_id
    ) then
      perform private.raise_app_error('archived_couple_exists');
    end if;

    if private.is_blocked_pair(
      target_couple.user_a_id,
      target_couple.user_b_id
    ) then
      perform private.raise_app_error('user_blocked');
    end if;

    update public.couples
    set
      status = 'active',
      connected_at = now(),
      disconnected_at = null,
      disconnected_by_user_id = null,
      archive_expires_at = null,
      disconnect_reason = null
    where id = target_couple.id
    returning * into target_couple;

    delete from public.couple_reconnect_invites
    where couple_id = target_couple.id;

    return target_couple;
  end if;

  if exists (
    select 1
    from public.couples as c
    where c.status = 'disconnected'
      and c.disconnect_reason is distinct from 'user_block'
      and c.archive_expires_at is not null
      and c.archive_expires_at > now()
      and (
        c.user_a_id = current_user_id
        or c.user_b_id = current_user_id
      )
  ) then
    perform private.raise_app_error('archived_couple_exists');
  end if;

  select c.*
  into target_couple
  from public.couples as c
  where c.invite_code = normalized_code
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

  if private.is_blocked_pair(target_couple.user_a_id, current_user_id) then
    perform private.raise_app_error('user_blocked');
  end if;

  update public.couples
  set
    user_b_id = current_user_id,
    status = 'active',
    connected_at = now(),
    disconnect_reason = null
  where id = target_couple.id
  returning * into target_couple;

  return target_couple;
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
    archive_expires_at = now() + interval '30 days',
    disconnect_reason = 'manual'
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
  current_user_id uuid := auth.uid();
  archived_couple_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select c.id
  into archived_couple_id
  from public.couples as c
  where c.status = 'disconnected'
    and c.disconnect_reason is distinct from 'user_block'
    and c.archive_expires_at is not null
    and c.archive_expires_at > now()
    and (
      c.user_a_id = current_user_id
      or c.user_b_id = current_user_id
    )
  order by c.created_at desc
  limit 1
  for update;

  if not found then
    return;
  end if;

  perform private.delete_couple_shared_data(archived_couple_id);
end;
$$;

create or replace function public.block_current_partner()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  partner_user_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  partner_user_id := case
    when active_couple.user_a_id = current_user_id
      then active_couple.user_b_id
    else active_couple.user_a_id
  end;

  if partner_user_id is null then
    perform private.raise_app_error('active_couple_required');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('couple_disconnect'),
    hashtext(active_couple.id::text)
  );

  insert into public.user_blocks (blocker_user_id, blocked_user_id)
  values (current_user_id, partner_user_id)
  on conflict (blocker_user_id, blocked_user_id) do nothing;

  update public.couples
  set
    status = 'disconnected',
    disconnected_at = now(),
    disconnected_by_user_id = current_user_id,
    archive_expires_at = now() + interval '30 days',
    disconnect_reason = 'user_block'
  where id = active_couple.id;

  delete from public.couple_reconnect_invites
  where couple_id = active_couple.id;

  perform private.bump_user_safety_states(
    array[current_user_id, partner_user_id]
  );
end;
$$;

create or replace function public.unblock_user(
  target_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  deleted_count integer;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if target_user_id is null or target_user_id = current_user_id then
    return false;
  end if;

  delete from public.user_blocks as ub
  where ub.blocker_user_id = current_user_id
    and ub.blocked_user_id = target_user_id;

  get diagnostics deleted_count = row_count;
  if deleted_count > 0 then
    perform private.bump_user_safety_states(
      array[current_user_id, target_user_id]
    );
  end if;

  return deleted_count > 0;
end;
$$;

create or replace function public.list_blocked_users()
returns table (
  user_id uuid,
  display_name text,
  blocked_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  return query
    select
      ub.blocked_user_id,
      p.display_name,
      ub.created_at
    from public.user_blocks as ub
    join public.profiles as p
      on p.id = ub.blocked_user_id
    where ub.blocker_user_id = current_user_id
    order by ub.created_at desc, ub.blocked_user_id;
end;
$$;

create or replace function public.list_reconnectable_couple_archives()
returns table (
  couple_id uuid,
  partner_user_id uuid,
  partner_display_name text,
  archive_expires_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if private.has_open_couple(current_user_id) then
    return;
  end if;

  return query
    select
      c.id,
      case
        when c.user_a_id = current_user_id then c.user_b_id
        else c.user_a_id
      end,
      p.display_name,
      c.archive_expires_at
    from public.couples as c
    join public.profiles as p
      on p.id = case
        when c.user_a_id = current_user_id then c.user_b_id
        else c.user_a_id
      end
    where c.status = 'disconnected'
      and c.disconnect_reason = 'user_block'
      and c.archive_expires_at is not null
      and c.archive_expires_at > now()
      and (
        c.user_a_id = current_user_id
        or c.user_b_id = current_user_id
      )
      and not private.is_blocked_pair(c.user_a_id, c.user_b_id)
    order by c.disconnected_at desc, c.id;
end;
$$;

create or replace function public.create_couple_archive_reconnect_invite(
  target_couple_id uuid
)
returns public.couples
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
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

  if private.has_open_couple(current_user_id) then
    perform private.raise_app_error('couple_already_exists');
  end if;

  select c.*
  into target_couple
  from public.couples as c
  where c.id = target_couple_id
    and c.status = 'disconnected'
    and c.disconnect_reason = 'user_block'
    and c.archive_expires_at is not null
    and c.archive_expires_at > now()
    and (
      c.user_a_id = current_user_id
      or c.user_b_id = current_user_id
    )
  for update;

  if not found then
    perform private.raise_app_error('blocked_archive_not_available');
  end if;

  if private.is_blocked_pair(
    target_couple.user_a_id,
    target_couple.user_b_id
  ) then
    perform private.raise_app_error('user_blocked');
  end if;

  reconnect_invite := private.create_or_replace_reconnect_invite(
    target_couple.id,
    current_user_id
  );

  update public.couples
  set invite_code = reconnect_invite.invite_code
  where id = target_couple.id
  returning * into target_couple;

  return target_couple;
end;
$$;

create or replace function private.is_current_user_character_storage_object(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select object_bucket_id = 'couple-characters'
    and exists (
      select 1
      from public.couples as c
      where c.status <> 'pending'
        and private.is_readable_couple_member(
          c.id,
          (select auth.uid())
        )
        and (
          c.status <> 'active'
          or c.character_setup_status <> 'pending'
          or c.user_b_id = (select auth.uid())
        )
        and (
          object_name in (
            c.id::text || '/current.png',
            c.id::text || '/current.json'
          )
          or (
            cardinality(regexp_split_to_array(object_name, '/')) = 4
            and split_part(object_name, '/', 1) = c.id::text
            and split_part(object_name, '/', 2) = 'revisions'
            and split_part(object_name, '/', 3)
              ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            and split_part(object_name, '/', 4) in (
              'preview.png',
              'drawing.json'
            )
          )
        )
    );
$$;

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
      where private.is_readable_couple_member(
          c.id,
          (select auth.uid())
        )
        and object_name like c.id::text || '/recordings/%'
    );
$$;

revoke execute on function private.is_blocked_pair(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function private.bump_user_safety_states(uuid[])
  from public, anon, authenticated;
revoke execute on function private.can_view_couple_context(uuid, uuid)
  from public, anon;
revoke execute on function private.prevent_blocked_couple_activation()
  from public, anon, authenticated;

grant execute on function private.can_view_couple_context(uuid, uuid)
  to authenticated;

revoke execute on function public.block_current_partner()
  from public, anon;
revoke execute on function public.delete_disconnected_couple_archive_now()
  from public, anon;
revoke execute on function public.unblock_user(uuid)
  from public, anon;
revoke execute on function public.list_blocked_users()
  from public, anon;
revoke execute on function public.list_reconnectable_couple_archives()
  from public, anon;
revoke execute on function public.create_couple_archive_reconnect_invite(uuid)
  from public, anon;

grant execute on function public.block_current_partner()
  to authenticated;
grant execute on function public.delete_disconnected_couple_archive_now()
  to authenticated;
grant execute on function public.unblock_user(uuid)
  to authenticated;
grant execute on function public.list_blocked_users()
  to authenticated;
grant execute on function public.list_reconnectable_couple_archives()
  to authenticated;
grant execute on function public.create_couple_archive_reconnect_invite(uuid)
  to authenticated;
