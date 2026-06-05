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

  return next;
end;
$$;
