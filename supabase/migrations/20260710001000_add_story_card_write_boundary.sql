alter table public.story_loop_cards
  add column if not exists artifact_revision uuid not null default gen_random_uuid(),
  add column if not exists background_image_path text,
  add column if not exists text_layer_count integer not null default 0,
  add column if not exists text_character_count integer not null default 0;

update public.story_loop_cards
set
  text_layer_count = case when has_text then 1 else 0 end,
  text_character_count = case when has_text then 1 else 0 end
where (has_text and (text_layer_count = 0 or text_character_count = 0))
  or (not has_text and (text_layer_count <> 0 or text_character_count <> 0));

delete from public.daily_questions as dq
using public.daily_story_loops as dsl
where dq.story_loop_id = dsl.id
  and not exists (
    select 1
    from public.story_loop_cards as slc
    where slc.story_loop_id = dsl.id
  );

delete from public.daily_story_loops as dsl
where not exists (
  select 1
  from public.story_loop_cards as slc
  where slc.story_loop_id = dsl.id
);

alter table public.story_loop_cards
  drop constraint if exists story_loop_cards_preview_path_check,
  drop constraint if exists story_loop_cards_scene_data_path_check,
  drop constraint if exists story_loop_cards_background_image_path_check,
  drop constraint if exists story_loop_cards_text_layer_count_check,
  drop constraint if exists story_loop_cards_text_character_count_check,
  drop constraint if exists story_loop_cards_text_content_check;

alter table public.story_loop_cards
  add constraint story_loop_cards_preview_path_check
    check (
      preview_path = couple_id::text
        || '/loops/'
        || couple_date::text
        || '/'
        || author_user_id::text
        || '/preview.png'
      or preview_path = couple_id::text
        || '/loops/'
        || couple_date::text
        || '/'
        || author_user_id::text
        || '/'
        || artifact_revision::text
        || '/preview.png'
    ),
  add constraint story_loop_cards_scene_data_path_check
    check (
      scene_data_path = couple_id::text
        || '/loops/'
        || couple_date::text
        || '/'
        || author_user_id::text
        || '/scene.json'
      or scene_data_path = couple_id::text
        || '/loops/'
        || couple_date::text
        || '/'
        || author_user_id::text
        || '/'
        || artifact_revision::text
        || '/scene.json'
    ),
  add constraint story_loop_cards_background_image_path_check
    check (
      background_image_path is null
      or background_image_path = couple_id::text
        || '/loops/'
        || couple_date::text
        || '/'
        || author_user_id::text
        || '/'
        || artifact_revision::text
        || '/background.jpg'
    ),
  add constraint story_loop_cards_text_layer_count_check
    check (text_layer_count between 0 and 10),
  add constraint story_loop_cards_text_character_count_check
    check (text_character_count between 0 and 5000),
  add constraint story_loop_cards_text_content_check
    check (
      (has_text and text_layer_count between 1 and 10 and text_character_count between 1 and 5000)
      or (not has_text and text_layer_count = 0 and text_character_count = 0)
    );

create or replace function private.is_current_user_readable_story_card_storage_object(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select object_bucket_id = 'story-cards'
    and exists (
      select 1
      from public.couples as c
      where private.is_readable_couple_member(c.id, (select auth.uid()))
        and split_part(object_name, '/', 1) = c.id::text
        and split_part(object_name, '/', 2) = 'loops'
        and split_part(object_name, '/', 3) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        and (
          split_part(object_name, '/', 4) = c.user_a_id::text
          or (
            c.user_b_id is not null
            and split_part(object_name, '/', 4) = c.user_b_id::text
          )
        )
        and (
          (
            cardinality(regexp_split_to_array(object_name, '/')) = 5
            and (
              split_part(object_name, '/', 5) = 'preview.png'
              or (
                c.status = 'active'
                and split_part(object_name, '/', 5) = 'scene.json'
              )
            )
          )
          or (
            cardinality(regexp_split_to_array(object_name, '/')) = 6
            and split_part(object_name, '/', 5) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            and (
              split_part(object_name, '/', 6) = 'preview.png'
              or (
                c.status = 'active'
                and split_part(object_name, '/', 6) in ('scene.json', 'background.jpg')
              )
            )
          )
        )
    );
$$;

create or replace function private.is_current_user_writable_story_card_storage_object(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select object_bucket_id = 'story-cards'
    and cardinality(regexp_split_to_array(object_name, '/')) = 6
    and split_part(object_name, '/', 2) = 'loops'
    and split_part(object_name, '/', 3) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    and split_part(object_name, '/', 5) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and split_part(object_name, '/', 6) in (
      'preview.png',
      'scene.json',
      'background.jpg'
    )
    and exists (
      select 1
      from public.couples as c
      where c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and split_part(object_name, '/', 1) = c.id::text
        and split_part(object_name, '/', 4) = (select auth.uid())::text
    );
$$;

create or replace function private.enqueue_story_card_artifact_cleanup(
  target_couple_id uuid,
  target_preview_path text,
  target_scene_data_path text,
  target_background_image_path text,
  target_cleanup_reason text default 'orphan_story_card'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_path text;
begin
  foreach target_path in array array[
    target_preview_path,
    target_scene_data_path,
    target_background_image_path
  ]
  loop
    if target_path is not null and btrim(target_path) <> '' then
      perform private.enqueue_storage_cleanup_request(
        'story-cards',
        target_path,
        target_cleanup_reason,
        target_couple_id
      );
    end if;
  end loop;
end;
$$;

create or replace function private.enqueue_deleted_story_loop_card_artifacts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.enqueue_story_card_artifact_cleanup(
    old.couple_id,
    old.preview_path,
    old.scene_data_path,
    old.background_image_path
  );

  return old;
end;
$$;

drop trigger if exists story_loop_cards_enqueue_storage_cleanup on public.story_loop_cards;

create trigger story_loop_cards_enqueue_storage_cleanup
  after delete on public.story_loop_cards
  for each row
  execute function private.enqueue_deleted_story_loop_card_artifacts();

create or replace function private.story_card_artifact_path(
  target_couple_id uuid,
  target_couple_date date,
  target_user_id uuid,
  target_artifact_revision uuid,
  target_file_name text
)
returns text
language sql
immutable
set search_path = ''
as $$
  select target_couple_id::text
    || '/loops/'
    || target_couple_date::text
    || '/'
    || target_user_id::text
    || '/'
    || target_artifact_revision::text
    || '/'
    || target_file_name;
$$;

create or replace function private.assign_question_to_story_loop(
  target_couple public.couples,
  target_story_loop public.daily_story_loops
)
returns public.daily_questions
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_daily_question public.daily_questions%rowtype;
  assignment_count integer;
  active_question_count integer;
  selected_question_id uuid;
begin
  select *
  into target_daily_question
  from public.daily_questions as dq
  where dq.story_loop_id = target_story_loop.id
  for update;

  if found then
    return target_daily_question;
  end if;

  select count(*)
  into active_question_count
  from public.questions as q
  where q.source = 'curated'
    and q.is_active = true;

  if active_question_count = 0 then
    perform private.raise_app_error('question_pool_empty');
  end if;

  select count(*)
  into assignment_count
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id;

  select q.id
  into selected_question_id
  from public.questions as q
  where q.source = 'curated'
    and q.is_active = true
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.couple_id = target_couple.id
        and dq.question_id = q.id
    )
  order by q.created_at, q.id
  limit 1;

  if selected_question_id is null then
    select q.id
    into selected_question_id
    from public.questions as q
    where q.source = 'curated'
      and q.is_active = true
    order by q.created_at, q.id
    offset assignment_count % active_question_count
    limit 1;
  end if;

  insert into public.daily_questions (
    couple_id,
    question_id,
    assigned_date,
    story_loop_id
  )
  values (
    target_couple.id,
    selected_question_id,
    target_story_loop.couple_date,
    target_story_loop.id
  )
  on conflict on constraint daily_questions_couple_date_unique do nothing;

  select *
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id
    and dq.assigned_date = target_story_loop.couple_date
  for update;

  if not found or target_daily_question.story_loop_id <> target_story_loop.id then
    perform private.raise_app_error('question_assignment_failed');
  end if;

  return target_daily_question;
end;
$$;

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
  target_daily_question public.daily_questions%rowtype;
  partner_user_id uuid;
  saved_card_count integer;
  normalized_preview_path text := btrim(requested_preview_path);
  normalized_scene_data_path text := btrim(requested_scene_data_path);
  normalized_background_image_path text := nullif(
    btrim(requested_background_image_path),
    ''
  );
  did_generate_question boolean := false;
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
    target_daily_question := private.assign_question_to_story_loop(
      active_couple,
      target_story_loop
    );

    update public.daily_story_loops as dsl
    set
      status = 'question_generated',
      question_generated_at = now(),
      story_edit_locked_at = now()
    where dsl.id = target_story_loop.id
    returning * into target_story_loop;

    insert into public.story_loop_notification_events (
      couple_id,
      story_loop_id,
      card_id,
      sender_user_id,
      receiver_user_id,
      event_type
    )
    select
      active_couple.id,
      target_story_loop.id,
      saved_card.id,
      current_user_id,
      receiver_user_id,
      'question_generated'
    from unnest(array[active_couple.user_a_id, active_couple.user_b_id])
      as receiver_user_id
    where receiver_user_id is not null;

    did_generate_question := true;
  end if;

  return query
    select
      target_story_loop.id,
      target_story_loop.status,
      saved_card.id,
      saved_card.revision,
      did_generate_question,
      target_daily_question.id;
end;
$$;

create or replace function public.delete_today_story_loop_card(
  expected_revision integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  current_couple_date date;
  target_story_loop public.daily_story_loops%rowtype;
  target_card public.story_loop_cards%rowtype;
  remaining_card_count integer;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if expected_revision is null or expected_revision < 1 then
    perform private.raise_app_error('story_card_revision_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  current_couple_date := private.current_date_in_timezone(active_couple.timezone);

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
    perform private.raise_app_error('story_card_not_found');
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
  into target_card
  from public.story_loop_cards as slc
  where slc.story_loop_id = target_story_loop.id
    and slc.author_user_id = current_user_id
  for update;

  if not found then
    perform private.raise_app_error('story_card_not_found');
  end if;

  if target_card.revision <> expected_revision then
    perform private.raise_app_error('story_card_revision_conflict');
  end if;

  delete from public.story_loop_cards
  where id = target_card.id;

  select count(*)::integer
  into remaining_card_count
  from public.story_loop_cards as slc
  where slc.story_loop_id = target_story_loop.id;

  if remaining_card_count = 0 then
    delete from public.daily_story_loops
    where id = target_story_loop.id;
  else
    update public.daily_story_loops as dsl
    set status = 'waiting_partner_card'
    where dsl.id = target_story_loop.id;
  end if;
end;
$$;

create or replace function public.discard_uploaded_story_loop_card_artifacts(
  requested_artifact_revision uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  current_couple_date date;
  target_path text;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_artifact_revision is null then
    perform private.raise_app_error('invalid_story_card_artifact_revision');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  current_couple_date := private.current_date_in_timezone(active_couple.timezone);

  if exists (
    select 1
    from public.story_loop_cards as slc
    where slc.couple_id = active_couple.id
      and slc.couple_date = current_couple_date
      and slc.author_user_id = current_user_id
      and slc.artifact_revision = requested_artifact_revision
  ) then
    return;
  end if;

  foreach target_path in array array[
    private.story_card_artifact_path(
      active_couple.id,
      current_couple_date,
      current_user_id,
      requested_artifact_revision,
      'preview.png'
    ),
    private.story_card_artifact_path(
      active_couple.id,
      current_couple_date,
      current_user_id,
      requested_artifact_revision,
      'scene.json'
    ),
    private.story_card_artifact_path(
      active_couple.id,
      current_couple_date,
      current_user_id,
      requested_artifact_revision,
      'background.jpg'
    )
  ]
  loop
    if exists (
      select 1
      from storage.objects as so
      where so.bucket_id = 'story-cards'
        and so.name = target_path
    ) then
      perform private.enqueue_storage_cleanup_request(
        'story-cards',
        target_path,
        'orphan_story_card',
        active_couple.id
      );
    end if;
  end loop;
end;
$$;

create or replace function public.get_my_today_story_loop_card_for_editing()
returns table (
  story_loop_id uuid,
  card_id uuid,
  card_revision integer,
  artifact_revision uuid,
  preview_path text,
  scene_data_path text,
  background_image_path text,
  has_photo boolean,
  has_drawing boolean,
  has_text boolean,
  text_layer_count integer,
  text_character_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  current_couple_date date;
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
    return;
  end if;

  return query
    select
      dsl.id,
      slc.id,
      slc.revision,
      slc.artifact_revision,
      slc.preview_path,
      slc.scene_data_path,
      slc.background_image_path,
      slc.has_photo,
      slc.has_drawing,
      slc.has_text,
      slc.text_layer_count,
      slc.text_character_count
    from public.daily_story_loops as dsl
    join public.story_loop_cards as slc
      on slc.story_loop_id = dsl.id
    where dsl.couple_id = active_couple.id
      and dsl.couple_date = current_couple_date
      and dsl.status = 'waiting_partner_card'
      and dsl.story_edit_locked_at is null
      and slc.author_user_id = current_user_id;
end;
$$;

revoke execute on function private.enqueue_story_card_artifact_cleanup(
  uuid,
  text,
  text,
  text,
  text
) from public, anon, authenticated;
revoke execute on function private.enqueue_deleted_story_loop_card_artifacts()
  from public, anon, authenticated;
revoke execute on function private.story_card_artifact_path(uuid, date, uuid, uuid, text)
  from public, anon, authenticated;
revoke execute on function private.assign_question_to_story_loop(
  public.couples,
  public.daily_story_loops
) from public, anon, authenticated;

revoke execute on function public.upsert_today_story_loop_card(
  uuid,
  text,
  text,
  text,
  boolean,
  boolean,
  boolean,
  integer,
  integer,
  integer
) from public, anon;
revoke execute on function public.delete_today_story_loop_card(integer)
  from public, anon;
revoke execute on function public.discard_uploaded_story_loop_card_artifacts(uuid)
  from public, anon;
revoke execute on function public.get_my_today_story_loop_card_for_editing()
  from public, anon;

grant execute on function public.upsert_today_story_loop_card(
  uuid,
  text,
  text,
  text,
  boolean,
  boolean,
  boolean,
  integer,
  integer,
  integer
) to authenticated;
grant execute on function public.delete_today_story_loop_card(integer)
  to authenticated;
grant execute on function public.discard_uploaded_story_loop_card_artifacts(uuid)
  to authenticated;
grant execute on function public.get_my_today_story_loop_card_for_editing()
  to authenticated;
