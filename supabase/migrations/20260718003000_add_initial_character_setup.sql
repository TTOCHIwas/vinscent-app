alter table public.couples
add column character_setup_status text;

update public.couples as c
set character_setup_status = case
  when c.status = 'pending' then 'pending'
  when exists (
    select 1
    from public.couple_characters as cc
    where cc.couple_id = c.id
  ) then 'custom'
  else 'default'
end;

alter table public.couples
alter column character_setup_status set default 'pending',
alter column character_setup_status set not null;

alter table public.couples
add constraint couples_character_setup_status_check
check (character_setup_status in ('pending', 'custom', 'default'));

drop function public.get_current_couple_context();
drop function private.get_current_couple_context();

create function private.get_current_couple_context()
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

create function public.get_current_couple_context()
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
language sql
security definer
set search_path = ''
as $$
  select *
  from private.get_current_couple_context();
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

  if target_couple.character_setup_status = 'pending'
    and target_couple.user_b_id <> current_user_id
  then
    perform private.raise_app_error('initial_setup_owner_required');
  end if;

  update public.couples
  set relationship_start_date = start_date
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
      where (
          c.status = 'active'
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
        and (
          c.status <> 'active'
          or c.character_setup_status <> 'pending'
          or c.user_b_id = (select auth.uid())
        )
        and object_name in (
          c.id::text || '/current.png',
          c.id::text || '/current.json'
        )
    );
$$;

create or replace function public.upsert_couple_character(
  character_image_path text,
  character_drawing_data_path text
)
returns table (
  couple_id uuid,
  image_path text,
  drawing_data_path text,
  updated_by uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  expected_image_path text;
  expected_drawing_data_path text;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if active_couple.character_setup_status = 'pending' then
    if active_couple.user_b_id <> current_user_id then
      perform private.raise_app_error('initial_setup_owner_required');
    end if;

    if active_couple.relationship_start_date is null then
      perform private.raise_app_error('relationship_date_required');
    end if;
  end if;

  expected_image_path := active_couple.id::text || '/current.png';
  expected_drawing_data_path := active_couple.id::text || '/current.json';

  if character_image_path <> expected_image_path
    or character_drawing_data_path <> expected_drawing_data_path
  then
    perform private.raise_app_error('invalid_character_path');
  end if;

  insert into public.couple_characters (
    couple_id,
    image_path,
    drawing_data_path,
    updated_by
  )
  values (
    active_couple.id,
    character_image_path,
    character_drawing_data_path,
    current_user_id
  )
  on conflict on constraint couple_characters_pkey
  do update
    set
      image_path = excluded.image_path,
      drawing_data_path = excluded.drawing_data_path,
      updated_by = excluded.updated_by
  returning
    public.couple_characters.couple_id,
    public.couple_characters.image_path,
    public.couple_characters.drawing_data_path,
    public.couple_characters.updated_by,
    public.couple_characters.created_at,
    public.couple_characters.updated_at
  into
    couple_id,
    image_path,
    drawing_data_path,
    updated_by,
    created_at,
    updated_at;

  update public.couples
  set character_setup_status = 'custom'
  where id = active_couple.id;

  return next;
end;
$$;

create function public.use_default_couple_character()
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

  if active_couple.character_setup_status = 'default' then
    return;
  end if;

  if active_couple.character_setup_status <> 'pending'
    or active_couple.user_b_id <> current_user_id
  then
    perform private.raise_app_error('initial_setup_owner_required');
  end if;

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  update public.couples
  set character_setup_status = 'default'
  where id = active_couple.id;
end;
$$;

revoke execute on function private.get_current_couple_context()
  from public, anon, authenticated;
revoke execute on function private.is_current_user_character_storage_object(text, text)
  from public, anon;
revoke execute on function public.get_current_couple_context()
  from public, anon;
revoke execute on function public.use_default_couple_character()
  from public, anon;

grant execute on function private.is_current_user_character_storage_object(text, text)
  to authenticated;
grant execute on function public.get_current_couple_context()
  to authenticated;
grant execute on function public.use_default_couple_character()
  to authenticated;
