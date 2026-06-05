insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'couple-characters',
  'couple-characters',
  false,
  1048576,
  array['image/png', 'application/json']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table public.couple_characters (
  couple_id uuid primary key references public.couples(id) on delete cascade,
  image_path text not null,
  drawing_data_path text not null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint couple_characters_image_path_check
    check (image_path = couple_id::text || '/current.png'),
  constraint couple_characters_drawing_data_path_check
    check (drawing_data_path = couple_id::text || '/current.json')
);

alter table public.couple_characters enable row level security;

create trigger couple_characters_set_updated_at
  before update on public.couple_characters
  for each row
  execute function public.set_updated_at();

create or replace function private.is_active_couple_member(
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
      and c.status = 'active'
      and (
        c.user_a_id = target_user_id
        or c.user_b_id = target_user_id
      )
  );
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
      where c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and object_name in (
          c.id::text || '/current.png',
          c.id::text || '/current.json'
        )
    );
$$;

create policy "couple_characters_select_member"
  on public.couple_characters
  for select
  to authenticated
  using (
    private.is_active_couple_member(couple_id, (select auth.uid()))
  );

create policy "couple_characters_storage_select_member"
  on storage.objects
  for select
  to authenticated
  using (
    private.is_current_user_character_storage_object(bucket_id, name)
  );

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

create or replace function public.get_couple_character()
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
  active_couple public.couples%rowtype;
begin
  active_couple := private.get_active_couple_for_current_user();

  return query
    select
      cc.couple_id,
      cc.image_path,
      cc.drawing_data_path,
      cc.updated_by,
      cc.created_at,
      cc.updated_at
    from public.couple_characters as cc
    where cc.couple_id = active_couple.id;
end;
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
  on conflict (couple_id)
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

  return next;
end;
$$;

revoke execute on function private.is_active_couple_member(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function private.is_current_user_character_storage_object(text, text)
  from public, anon, authenticated;

revoke execute on function public.get_couple_character()
  from public, anon;
revoke execute on function public.upsert_couple_character(text, text)
  from public, anon;

grant execute on function public.get_couple_character()
  to authenticated;
grant execute on function public.upsert_couple_character(text, text)
  to authenticated;
