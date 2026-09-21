alter table public.story_loop_cards
  add column layout_version integer not null default 1,
  add constraint story_loop_cards_layout_version_check
    check (layout_version in (1, 2));

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
    has_drawing = coalesce(requested_has_drawing, false),
    layout_version = 1
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

create function public.upsert_today_story_loop_card_v3(
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
  requested_layout_version integer,
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
  saved record;
begin
  if auth.uid() is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_layout_version is null
    or requested_layout_version not in (1, 2)
  then
    perform private.raise_app_error('invalid_story_card_layout_version');
  end if;

  select *
  into saved
  from public.upsert_today_story_loop_card_v2(
    requested_artifact_revision,
    requested_preview_path,
    requested_scene_data_path,
    requested_background_image_path,
    requested_has_photo,
    requested_has_drawing,
    requested_has_text,
    requested_text_layer_count,
    requested_text_character_count,
    requested_card_type,
    requested_photo_count,
    requested_has_caption,
    expected_revision
  );

  update public.story_loop_cards as card
  set layout_version = requested_layout_version
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

create function public.get_today_story_card_stacks_v3()
returns table (
  couple_id uuid,
  couple_date date,
  access_mode text,
  can_create_card boolean,
  author_user_id uuid,
  latest_card_id uuid,
  latest_card_preview_path text,
  latest_card_type text,
  latest_layout_version integer,
  latest_card_submitted_at timestamptz,
  latest_card_is_featured boolean,
  card_count integer,
  is_mine boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.raise_app_error('auth_required');
  end if;

  return query
    select
      stack.couple_id,
      stack.couple_date,
      stack.access_mode,
      stack.can_create_card,
      stack.author_user_id,
      stack.latest_card_id,
      stack.latest_card_preview_path,
      stack.latest_card_type,
      coalesce(card.layout_version, 1)::integer,
      stack.latest_card_submitted_at,
      stack.latest_card_is_featured,
      stack.card_count,
      stack.is_mine
    from public.get_today_story_card_stacks_v2() as stack
    left join public.story_loop_cards as card
      on card.id = stack.latest_card_id;
end;
$$;

create function public.get_story_card_stack_v3(
  target_date date,
  target_author_user_id uuid
)
returns table (
  "position" integer,
  card_id uuid,
  author_user_id uuid,
  preview_path text,
  scene_data_path text,
  card_type text,
  layout_version integer,
  has_photo boolean,
  has_drawing boolean,
  has_text boolean,
  submitted_at timestamptz,
  revision integer,
  is_featured boolean,
  can_delete boolean,
  can_feature boolean,
  is_read boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.raise_app_error('auth_required');
  end if;

  return query
    select
      stack.position,
      stack.card_id,
      stack.author_user_id,
      stack.preview_path,
      stack.scene_data_path,
      stack.card_type,
      coalesce(card.layout_version, 1)::integer,
      stack.has_photo,
      stack.has_drawing,
      stack.has_text,
      stack.submitted_at,
      stack.revision,
      stack.is_featured,
      stack.can_delete,
      stack.can_feature,
      stack.is_read
    from public.get_story_card_stack_v2(
      target_date,
      target_author_user_id
    ) as stack
    left join public.story_loop_cards as card
      on card.id = stack.card_id;
end;
$$;

create function public.get_today_story_loop_summary_v3()
returns table (
  couple_id uuid,
  couple_date date,
  access_mode text,
  loop_id uuid,
  loop_status text,
  story_edit_locked boolean,
  can_edit_story boolean,
  can_answer_question boolean,
  card_count integer,
  first_card_id uuid,
  first_card_author_user_id uuid,
  first_card_preview_path text,
  first_card_type text,
  first_card_layout_version integer,
  first_card_submitted_at timestamptz,
  second_card_id uuid,
  second_card_author_user_id uuid,
  second_card_preview_path text,
  second_card_type text,
  second_card_layout_version integer,
  second_card_submitted_at timestamptz,
  daily_question_id uuid,
  question_id uuid,
  question_text text,
  question_source text,
  question_category text,
  question_mood text,
  question_status text,
  my_answer_exists boolean,
  partner_answer_exists boolean,
  answer_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.raise_app_error('auth_required');
  end if;

  return query
    select
      summary.couple_id,
      summary.couple_date,
      summary.access_mode,
      summary.loop_id,
      summary.loop_status,
      summary.story_edit_locked,
      summary.can_edit_story,
      summary.can_answer_question,
      summary.card_count,
      summary.first_card_id,
      summary.first_card_author_user_id,
      summary.first_card_preview_path,
      summary.first_card_type,
      coalesce(first_card.layout_version, 1)::integer,
      summary.first_card_submitted_at,
      summary.second_card_id,
      summary.second_card_author_user_id,
      summary.second_card_preview_path,
      summary.second_card_type,
      coalesce(second_card.layout_version, 1)::integer,
      summary.second_card_submitted_at,
      summary.daily_question_id,
      summary.question_id,
      summary.question_text,
      summary.question_source,
      summary.question_category,
      summary.question_mood,
      summary.question_status,
      summary.my_answer_exists,
      summary.partner_answer_exists,
      summary.answer_count
    from public.get_today_story_loop_summary_v2() as summary
    left join public.story_loop_cards as first_card
      on first_card.id = summary.first_card_id
    left join public.story_loop_cards as second_card
      on second_card.id = summary.second_card_id;
end;
$$;

create function public.get_story_loop_detail_v3(target_date date)
returns table (
  couple_id uuid,
  couple_date date,
  access_mode text,
  loop_id uuid,
  loop_status text,
  story_edit_locked boolean,
  can_edit_story boolean,
  can_answer_question boolean,
  card_count integer,
  first_card_id uuid,
  first_card_author_user_id uuid,
  first_card_preview_path text,
  first_card_scene_data_path text,
  first_card_type text,
  first_card_layout_version integer,
  first_card_has_photo boolean,
  first_card_has_drawing boolean,
  first_card_has_text boolean,
  first_card_submitted_at timestamptz,
  first_card_revision integer,
  second_card_id uuid,
  second_card_author_user_id uuid,
  second_card_preview_path text,
  second_card_scene_data_path text,
  second_card_type text,
  second_card_layout_version integer,
  second_card_has_photo boolean,
  second_card_has_drawing boolean,
  second_card_has_text boolean,
  second_card_submitted_at timestamptz,
  second_card_revision integer,
  daily_question_id uuid,
  question_id uuid,
  question_text text,
  question_source text,
  question_category text,
  question_mood text,
  question_status text,
  my_answer_id uuid,
  my_answer_text text,
  my_answer_answered_at timestamptz,
  my_answer_updated_at timestamptz,
  partner_answer_exists boolean,
  partner_answer_id uuid,
  partner_answer_text text,
  partner_answer_answered_at timestamptz,
  partner_answer_updated_at timestamptz,
  answer_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.raise_app_error('auth_required');
  end if;

  return query
    select
      detail.couple_id,
      detail.couple_date,
      detail.access_mode,
      detail.loop_id,
      detail.loop_status,
      detail.story_edit_locked,
      detail.can_edit_story,
      detail.can_answer_question,
      detail.card_count,
      detail.first_card_id,
      detail.first_card_author_user_id,
      detail.first_card_preview_path,
      detail.first_card_scene_data_path,
      detail.first_card_type,
      coalesce(first_card.layout_version, 1)::integer,
      detail.first_card_has_photo,
      detail.first_card_has_drawing,
      detail.first_card_has_text,
      detail.first_card_submitted_at,
      detail.first_card_revision,
      detail.second_card_id,
      detail.second_card_author_user_id,
      detail.second_card_preview_path,
      detail.second_card_scene_data_path,
      detail.second_card_type,
      coalesce(second_card.layout_version, 1)::integer,
      detail.second_card_has_photo,
      detail.second_card_has_drawing,
      detail.second_card_has_text,
      detail.second_card_submitted_at,
      detail.second_card_revision,
      detail.daily_question_id,
      detail.question_id,
      detail.question_text,
      detail.question_source,
      detail.question_category,
      detail.question_mood,
      detail.question_status,
      detail.my_answer_id,
      detail.my_answer_text,
      detail.my_answer_answered_at,
      detail.my_answer_updated_at,
      detail.partner_answer_exists,
      detail.partner_answer_id,
      detail.partner_answer_text,
      detail.partner_answer_answered_at,
      detail.partner_answer_updated_at,
      detail.answer_count
    from public.get_story_loop_detail_v2(target_date) as detail
    left join public.story_loop_cards as first_card
      on first_card.id = detail.first_card_id
    left join public.story_loop_cards as second_card
      on second_card.id = detail.second_card_id;
end;
$$;

create function public.get_story_loop_month_summary_v3(target_month date)
returns table (
  couple_date date,
  loop_status text,
  card_count integer,
  first_card_id uuid,
  first_card_author_user_id uuid,
  first_card_preview_path text,
  first_card_type text,
  first_card_layout_version integer,
  first_card_submitted_at timestamptz,
  second_card_id uuid,
  second_card_author_user_id uuid,
  second_card_preview_path text,
  second_card_type text,
  second_card_layout_version integer,
  second_card_submitted_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    perform private.raise_app_error('auth_required');
  end if;

  return query
    select
      summary.couple_date,
      summary.loop_status,
      summary.card_count,
      summary.first_card_id,
      summary.first_card_author_user_id,
      summary.first_card_preview_path,
      summary.first_card_type,
      coalesce(first_card.layout_version, 1)::integer,
      summary.first_card_submitted_at,
      summary.second_card_id,
      summary.second_card_author_user_id,
      summary.second_card_preview_path,
      summary.second_card_type,
      coalesce(second_card.layout_version, 1)::integer,
      summary.second_card_submitted_at
    from public.get_story_loop_month_summary_v2(target_month) as summary
    left join public.story_loop_cards as first_card
      on first_card.id = summary.first_card_id
    left join public.story_loop_cards as second_card
      on second_card.id = summary.second_card_id;
end;
$$;

revoke execute on function public.upsert_today_story_loop_card_v3(
  uuid, text, text, text, boolean, boolean, boolean,
  integer, integer, text, integer, boolean, integer, integer
) from public, anon;
revoke execute on function public.get_today_story_card_stacks_v3()
  from public, anon;
revoke execute on function public.get_story_card_stack_v3(date, uuid)
  from public, anon;
revoke execute on function public.get_today_story_loop_summary_v3()
  from public, anon;
revoke execute on function public.get_story_loop_detail_v3(date)
  from public, anon;
revoke execute on function public.get_story_loop_month_summary_v3(date)
  from public, anon;

grant execute on function public.upsert_today_story_loop_card_v3(
  uuid, text, text, text, boolean, boolean, boolean,
  integer, integer, text, integer, boolean, integer, integer
) to authenticated;
grant execute on function public.get_today_story_card_stacks_v3()
  to authenticated;
grant execute on function public.get_story_card_stack_v3(date, uuid)
  to authenticated;
grant execute on function public.get_today_story_loop_summary_v3()
  to authenticated;
grant execute on function public.get_story_loop_detail_v3(date)
  to authenticated;
grant execute on function public.get_story_loop_month_summary_v3(date)
  to authenticated;
