alter table public.daily_story_loops
  drop constraint daily_story_loops_status_check;

alter table public.daily_story_loops
  add constraint daily_story_loops_status_check
    check (
      status in (
        'waiting_partner_card',
        'card_only_completed',
        'question_preparing',
        'question_generated',
        'answered_by_one',
        'completed'
      )
    );

create or replace function private.is_ai_focused_foundation_in_progress(
  target_couple_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  active_curriculum_version integer;
  foundation_question_count integer;
  completed_foundation_count integer;
begin
  if not private.has_ai_feature_entitlement(
    target_couple_id,
    'focused_questions'
  ) then
    return false;
  end if;

  select aiqc.version, aiqc.question_count
  into active_curriculum_version, foundation_question_count
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if active_curriculum_version is null then
    return true;
  end if;

  select count(*)::integer
  into completed_foundation_count
  from private.completed_ai_foundation_question_ids(
    target_couple_id,
    active_curriculum_version
  );

  return completed_foundation_count < foundation_question_count;
end;
$$;

create or replace function private.finalize_story_loop_after_card_pair(
  target_couple public.couples,
  target_story_loop public.daily_story_loops,
  triggering_user_id uuid,
  triggering_card_id uuid
)
returns table (
  story_loop_status text,
  question_generated boolean,
  daily_question_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  saved_card_count integer;
  finalized_story_loop public.daily_story_loops%rowtype;
  target_daily_question public.daily_questions%rowtype;
begin
  select count(*)::integer
  into saved_card_count
  from public.story_loop_cards as slc
  where slc.story_loop_id = target_story_loop.id;

  if saved_card_count <> 2 then
    return query
      select target_story_loop.status, false, null::uuid;
    return;
  end if;

  if private.is_ai_focused_foundation_in_progress(target_couple.id) then
    update public.daily_story_loops as dsl
    set
      status = 'card_only_completed',
      question_generated_at = null,
      story_edit_locked_at = coalesce(dsl.story_edit_locked_at, now())
    where dsl.id = target_story_loop.id
    returning * into finalized_story_loop;

    return query
      select finalized_story_loop.status, false, null::uuid;
    return;
  end if;

  target_daily_question := private.assign_question_to_story_loop(
    target_couple,
    target_story_loop
  );

  update public.daily_story_loops as dsl
  set
    status = 'question_generated',
    question_generated_at = now(),
    story_edit_locked_at = coalesce(dsl.story_edit_locked_at, now())
  where dsl.id = target_story_loop.id
  returning * into finalized_story_loop;

  insert into public.story_loop_notification_events (
    couple_id,
    story_loop_id,
    card_id,
    sender_user_id,
    receiver_user_id,
    event_type
  )
  select
    target_couple.id,
    target_story_loop.id,
    triggering_card_id,
    triggering_user_id,
    receiver_user_id,
    'question_generated'
  from unnest(array[target_couple.user_a_id, target_couple.user_b_id])
    as receiver_user_id
  where receiver_user_id is not null;

  return query
    select finalized_story_loop.status, true, target_daily_question.id;
end;
$$;

revoke execute on function private.is_ai_focused_foundation_in_progress(uuid)
  from public, anon, authenticated;
revoke execute on function private.finalize_story_loop_after_card_pair(
  public.couples,
  public.daily_story_loops,
  uuid,
  uuid
) from public, anon, authenticated;

create or replace function public.upsert_today_story_loop_card(
  requested_artifact_revision uuid,
  requested_preview_path text,
  requested_scene_data_path text,
  requested_background_image_path text,
  requested_has_photo boolean,
  requested_has_drawing boolean,
  requested_has_text boolean,
  requested_text_layer_count integer,
  requested_text_character_count integer,
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
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  current_couple_date date;
  target_story_loop public.daily_story_loops%rowtype;
  existing_card public.story_loop_cards%rowtype;
  saved_card public.story_loop_cards%rowtype;
  partner_user_id uuid;
  saved_card_count integer;
  finalization_result record;
  normalized_preview_path text := btrim(requested_preview_path);
  normalized_scene_data_path text := btrim(requested_scene_data_path);
  normalized_background_image_path text := nullif(
    btrim(requested_background_image_path),
    ''
  );
  did_generate_question boolean := false;
  assigned_daily_question_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  current_couple_date := private.current_date_in_timezone(active_couple.timezone);

  if current_couple_date < active_couple.relationship_start_date then
    perform private.raise_app_error('story_not_ready');
  end if;

  if requested_artifact_revision is null then
    perform private.raise_app_error('invalid_story_card_artifact_revision');
  end if;

  if not coalesce(requested_has_photo, false)
    and not coalesce(requested_has_drawing, false)
    and not coalesce(requested_has_text, false)
  then
    perform private.raise_app_error('story_card_content_required');
  end if;

  if requested_text_layer_count is null
    or requested_text_layer_count < 0
    or requested_text_layer_count > 10
    or requested_text_character_count is null
    or requested_text_character_count < 0
    or requested_text_character_count > 5000
  then
    perform private.raise_app_error('invalid_story_card_text_content');
  end if;

  if coalesce(requested_has_text, false) then
    if requested_text_layer_count = 0 or requested_text_character_count = 0 then
      perform private.raise_app_error('invalid_story_card_text_content');
    end if;
  elsif requested_text_layer_count <> 0 or requested_text_character_count <> 0 then
    perform private.raise_app_error('invalid_story_card_text_content');
  end if;

  if normalized_preview_path is distinct from private.story_card_artifact_path(
    active_couple.id,
    current_couple_date,
    current_user_id,
    requested_artifact_revision,
    'preview.png'
  ) or normalized_scene_data_path is distinct from private.story_card_artifact_path(
    active_couple.id,
    current_couple_date,
    current_user_id,
    requested_artifact_revision,
    'scene.json'
  ) then
    perform private.raise_app_error('invalid_story_card_path');
  end if;

  if coalesce(requested_has_photo, false) then
    if normalized_background_image_path is distinct from private.story_card_artifact_path(
      active_couple.id,
      current_couple_date,
      current_user_id,
      requested_artifact_revision,
      'background.jpg'
    ) then
      perform private.raise_app_error('invalid_story_card_background_path');
    end if;
  elsif normalized_background_image_path is not null then
    perform private.raise_app_error('invalid_story_card_background_path');
  end if;

  if not exists (
    select 1
    from storage.objects as so
    where so.bucket_id = 'story-cards'
      and so.name = normalized_preview_path
  ) or not exists (
    select 1
    from storage.objects as so
    where so.bucket_id = 'story-cards'
      and so.name = normalized_scene_data_path
  ) or (
    normalized_background_image_path is not null
    and not exists (
      select 1
      from storage.objects as so
      where so.bucket_id = 'story-cards'
        and so.name = normalized_background_image_path
    )
  ) then
    perform private.raise_app_error('story_card_artifact_missing');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('story_loop_card_write'),
    hashtext(active_couple.id::text || ':' || current_couple_date::text)
  );

  select *
  into target_story_loop
  from public.daily_story_loops as dsl
  where dsl.couple_id = active_couple.id
    and dsl.couple_date = current_couple_date
  for update;

  if not found then
    insert into public.daily_story_loops (
      couple_id,
      couple_date,
      status
    )
    values (
      active_couple.id,
      current_couple_date,
      'waiting_partner_card'
    )
    on conflict on constraint daily_story_loops_couple_date_unique do nothing;

    select *
    into target_story_loop
    from public.daily_story_loops as dsl
    where dsl.couple_id = active_couple.id
      and dsl.couple_date = current_couple_date
    for update;
  end if;

  if target_story_loop.story_edit_locked_at is not null
    or target_story_loop.status <> 'waiting_partner_card'
    or exists (
      select 1
      from public.daily_questions as dq
      where dq.story_loop_id = target_story_loop.id
    )
  then
    perform private.raise_app_error('story_card_locked');
  end if;

  select *
  into existing_card
  from public.story_loop_cards as slc
  where slc.story_loop_id = target_story_loop.id
    and slc.author_user_id = current_user_id
  for update;

  if found then
    if expected_revision is null then
      perform private.raise_app_error('story_card_revision_required');
    end if;

    if expected_revision <> existing_card.revision then
      perform private.raise_app_error('story_card_revision_conflict');
    end if;

    update public.story_loop_cards as slc
    set
      artifact_revision = requested_artifact_revision,
      preview_path = normalized_preview_path,
      scene_data_path = normalized_scene_data_path,
      background_image_path = normalized_background_image_path,
      has_photo = requested_has_photo,
      has_drawing = requested_has_drawing,
      has_text = requested_has_text,
      text_layer_count = requested_text_layer_count,
      text_character_count = requested_text_character_count,
      revision = existing_card.revision + 1
    where slc.id = existing_card.id
    returning * into saved_card;

    perform private.enqueue_story_card_artifact_cleanup(
      existing_card.couple_id,
      existing_card.preview_path,
      existing_card.scene_data_path,
      existing_card.background_image_path
    );
  else
    if expected_revision is not null then
      perform private.raise_app_error('story_card_revision_conflict');
    end if;

    insert into public.story_loop_cards (
      story_loop_id,
      couple_id,
      couple_date,
      author_user_id,
      artifact_revision,
      preview_path,
      scene_data_path,
      background_image_path,
      has_photo,
      has_drawing,
      has_text,
      text_layer_count,
      text_character_count
    )
    values (
      target_story_loop.id,
      active_couple.id,
      current_couple_date,
      current_user_id,
      requested_artifact_revision,
      normalized_preview_path,
      normalized_scene_data_path,
      normalized_background_image_path,
      requested_has_photo,
      requested_has_drawing,
      requested_has_text,
      requested_text_layer_count,
      requested_text_character_count
    )
    returning * into saved_card;

    partner_user_id := case
      when active_couple.user_a_id = current_user_id then active_couple.user_b_id
      else active_couple.user_a_id
    end;

    if partner_user_id is not null then
      insert into public.story_loop_notification_events (
        couple_id,
        story_loop_id,
        card_id,
        sender_user_id,
        receiver_user_id,
        event_type
      )
      values (
        active_couple.id,
        target_story_loop.id,
        saved_card.id,
        current_user_id,
        partner_user_id,
        'partner_story_card_uploaded'
      );
    end if;
  end if;

  select count(*)::integer
  into saved_card_count
  from public.story_loop_cards as slc
  where slc.story_loop_id = target_story_loop.id;

  if saved_card_count = 2 then
    select *
    into finalization_result
    from private.finalize_story_loop_after_card_pair(
      active_couple,
      target_story_loop,
      current_user_id,
      saved_card.id
    );

    target_story_loop.status := finalization_result.story_loop_status;
    did_generate_question := finalization_result.question_generated;
    assigned_daily_question_id := finalization_result.daily_question_id;
  end if;

  return query
    select
      target_story_loop.id,
      target_story_loop.status,
      saved_card.id,
      saved_card.revision,
      did_generate_question,
      assigned_daily_question_id;
end;
$$;
