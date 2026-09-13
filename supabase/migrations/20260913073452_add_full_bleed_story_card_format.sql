create or replace function private.normalize_story_card_format_metadata()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.card_type := coalesce(nullif(btrim(new.card_type), ''), 'polaroid');
  if new.card_type in ('polaroid', 'full_bleed') then
    new.photo_count := case when coalesce(new.has_photo, false) then 1 else 0 end;
  end if;
  return new;
end;
$$;

alter table public.story_loop_cards
  drop constraint story_loop_cards_card_type_check,
  drop constraint story_loop_cards_format_metadata_check;

alter table public.story_loop_cards
  add constraint story_loop_cards_card_type_check
    check (
      card_type in (
        'full_bleed',
        'polaroid',
        'four_cut_grid',
        'four_cut_strip'
      )
    ),
  add constraint story_loop_cards_format_metadata_check
    check (
      (
        card_type in ('full_bleed', 'polaroid')
        and photo_count = case when has_photo then 1 else 0 end
      )
      or (
        card_type in ('four_cut_grid', 'four_cut_strip')
        and has_photo
        and photo_count = 4
        and background_image_path is null
      )
    );

create or replace function public.upsert_today_story_loop_card_v2(
  requested_artifact_revision uuid,
  requested_preview_path text,
  requested_scene_data_path text,
  requested_background_image_path text,
  requested_has_photo boolean,
  requested_has_drawing boolean,
  requested_has_text boolean,
  requested_text_layer_count integer,
  requested_text_character_count integer,
  requested_card_type text,
  requested_photo_count integer,
  requested_has_caption boolean,
  expected_revision integer default null
)
returns table (
  story_loop_id uuid,
  story_loop_status text,
  card_id uuid,
  card_revision integer,
  question_generated boolean,
  daily_question_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_card_type text := nullif(btrim(requested_card_type), '');
  is_four_cut boolean;
  legacy_has_photo boolean;
  legacy_has_drawing boolean;
  saved record;
begin
  if auth.uid() is null then
    perform private.raise_app_error('auth_required');
  end if;

  if normalized_card_type is null
    or normalized_card_type not in (
      'full_bleed',
      'polaroid',
      'four_cut_grid',
      'four_cut_strip'
    )
  then
    perform private.raise_app_error('invalid_story_card_type');
  end if;

  is_four_cut := normalized_card_type in ('four_cut_grid', 'four_cut_strip');

  if (
    not is_four_cut
    and requested_photo_count is distinct from case
      when coalesce(requested_has_photo, false) then 1
      else 0
    end
  ) or (
    is_four_cut
    and (
      requested_photo_count is distinct from 4
      or not coalesce(requested_has_photo, false)
    )
  ) then
    perform private.raise_app_error('invalid_story_card_photo_count');
  end if;

  if normalized_card_type <> 'polaroid'
    and coalesce(requested_has_caption, false)
  then
    perform private.raise_app_error('invalid_story_card_caption');
  end if;

  if is_four_cut
    and nullif(btrim(requested_background_image_path), '') is not null
  then
    perform private.raise_app_error('invalid_story_card_background_path');
  end if;

  legacy_has_photo := case
    when is_four_cut then false
    else coalesce(requested_has_photo, false)
  end;
  legacy_has_drawing := coalesce(requested_has_drawing, false)
    or (
      is_four_cut
      and not coalesce(requested_has_text, false)
    );

  select *
  into saved
  from public.upsert_today_story_loop_card(
    requested_artifact_revision,
    requested_preview_path,
    requested_scene_data_path,
    case when is_four_cut then null else requested_background_image_path end,
    legacy_has_photo,
    legacy_has_drawing,
    requested_has_text,
    requested_text_layer_count,
    requested_text_character_count,
    expected_revision
  );

  update public.story_loop_cards as card
  set
    card_type = normalized_card_type,
    photo_count = requested_photo_count,
    has_photo = coalesce(requested_has_photo, false),
    has_drawing = coalesce(requested_has_drawing, false)
  where card.id = saved.card_id;

  return query
    select
      saved.story_loop_id,
      saved.story_loop_status,
      saved.card_id,
      saved.card_revision,
      saved.question_generated,
      saved.daily_question_id;
end;
$$;
