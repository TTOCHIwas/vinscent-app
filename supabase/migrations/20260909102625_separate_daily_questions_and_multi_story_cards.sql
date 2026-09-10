alter table public.couples
  add column question_delivery_time time without time zone,
  add column question_delivery_time_set_at timestamptz,
  add column next_question_delivery_time time without time zone,
  add column next_question_delivery_time_effective_date date;

update public.couples
set
  question_delivery_time = '09:00:00'::time,
  question_delivery_time_set_at = coalesce(connected_at, updated_at, created_at)
where status in ('active', 'disconnected')
  and question_delivery_time is null;

alter table public.couples
  add constraint couples_question_delivery_time_minute_check
    check (
      question_delivery_time is null
      or extract(second from question_delivery_time) = 0
    ),
  add constraint couples_next_question_delivery_time_minute_check
    check (
      next_question_delivery_time is null
      or extract(second from next_question_delivery_time) = 0
    ),
  add constraint couples_next_question_delivery_time_state_check
    check (
      (
        next_question_delivery_time is null
        and next_question_delivery_time_effective_date is null
      )
      or (
        next_question_delivery_time is not null
        and next_question_delivery_time_effective_date is not null
      )
    );

create or replace function private.apply_due_question_delivery_time(
  target_couple_id uuid,
  requested_run_at timestamptz default now()
)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.couples as c
  set
    question_delivery_time = c.next_question_delivery_time,
    question_delivery_time_set_at = requested_run_at,
    next_question_delivery_time = null,
    next_question_delivery_time_effective_date = null
  where c.id = target_couple_id
    and c.next_question_delivery_time is not null
    and c.next_question_delivery_time_effective_date
      <= (requested_run_at at time zone c.timezone)::date;
$$;

revoke execute on function private.apply_due_question_delivery_time(
  uuid,
  timestamptz
) from public, anon, authenticated;

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
  question_delivery_time time without time zone,
  pending_question_delivery_time time without time zone,
  pending_question_delivery_time_effective_date date,
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
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  open_couple public.couples%rowtype;
  archived_couple public.couples%rowtype;
  reconnect_invite public.couple_reconnect_invites%rowtype;
  resolved_current_date date;
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
    resolved_current_date := private.current_date_in_timezone(
      open_couple.timezone
    );

    return query
      select
        open_couple.id,
        open_couple.invite_code,
        open_couple.user_a_id,
        open_couple.user_b_id,
        open_couple.relationship_start_date,
        open_couple.character_setup_status,
        open_couple.timezone,
        case
          when open_couple.next_question_delivery_time_effective_date
            <= resolved_current_date
            then open_couple.next_question_delivery_time
          else open_couple.question_delivery_time
        end,
        case
          when open_couple.next_question_delivery_time_effective_date
            > resolved_current_date
            then open_couple.next_question_delivery_time
          else null::time
        end,
        case
          when open_couple.next_question_delivery_time_effective_date
            > resolved_current_date
            then open_couple.next_question_delivery_time_effective_date
          else null::date
        end,
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
        resolved_current_date;

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

  resolved_current_date := private.current_date_in_timezone(
    archived_couple.timezone
  );

  return query
    select
      archived_couple.id,
      coalesce(reconnect_invite.invite_code, archived_couple.invite_code),
      archived_couple.user_a_id,
      archived_couple.user_b_id,
      archived_couple.relationship_start_date,
      archived_couple.character_setup_status,
      archived_couple.timezone,
      case
        when archived_couple.next_question_delivery_time_effective_date
          <= resolved_current_date
          then archived_couple.next_question_delivery_time
        else archived_couple.question_delivery_time
      end,
      case
        when archived_couple.next_question_delivery_time_effective_date
          > resolved_current_date
          then archived_couple.next_question_delivery_time
        else null::time
      end,
      case
        when archived_couple.next_question_delivery_time_effective_date
          > resolved_current_date
          then archived_couple.next_question_delivery_time_effective_date
        else null::date
      end,
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
      resolved_current_date;
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
  question_delivery_time time without time zone,
  pending_question_delivery_time time without time zone,
  pending_question_delivery_time_effective_date date,
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
stable
security definer
set search_path = ''
as $$
  select *
  from private.get_current_couple_context();
$$;

revoke execute on function private.get_current_couple_context()
  from public, anon, authenticated;
revoke execute on function public.get_current_couple_context()
  from public, anon;
grant execute on function public.get_current_couple_context()
  to authenticated;

create or replace function public.set_initial_question_delivery_time(
  requested_time time without time zone
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

  if requested_time is null or extract(second from requested_time) <> 0 then
    perform private.raise_app_error('invalid_question_delivery_time');
  end if;

  select c.*
  into target_couple
  from public.couples as c
  where c.status = 'active'
    and (c.user_a_id = current_user_id or c.user_b_id = current_user_id)
  for update;

  if not found then
    perform private.raise_app_error('active_couple_required');
  end if;

  if target_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if target_couple.character_setup_status = 'pending'
    and target_couple.user_b_id <> current_user_id
  then
    perform private.raise_app_error('initial_setup_owner_required');
  end if;

  if target_couple.question_delivery_time is not null then
    perform private.raise_app_error('question_delivery_time_already_set');
  end if;

  update public.couples as c
  set
    question_delivery_time = requested_time,
    question_delivery_time_set_at = now(),
    next_question_delivery_time = null,
    next_question_delivery_time_effective_date = null
  where c.id = target_couple.id
  returning c.* into target_couple;

  return target_couple;
end;
$$;

create or replace function public.schedule_question_delivery_time_update(
  requested_time time without time zone
)
returns public.couples
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  target_couple public.couples%rowtype;
  current_couple_date date;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_time is null or extract(second from requested_time) <> 0 then
    perform private.raise_app_error('invalid_question_delivery_time');
  end if;

  select c.*
  into target_couple
  from public.couples as c
  where c.status = 'active'
    and (c.user_a_id = current_user_id or c.user_b_id = current_user_id)
  for update;

  if not found then
    perform private.raise_app_error('active_couple_required');
  end if;

  perform private.apply_due_question_delivery_time(target_couple.id, now());

  select c.*
  into target_couple
  from public.couples as c
  where c.id = target_couple.id
  for update;

  if target_couple.question_delivery_time is null then
    perform private.raise_app_error('question_delivery_time_required');
  end if;

  current_couple_date := private.current_date_in_timezone(
    target_couple.timezone
  );

  update public.couples as c
  set
    next_question_delivery_time = requested_time,
    next_question_delivery_time_effective_date = current_couple_date + 1
  where c.id = target_couple.id
  returning c.* into target_couple;

  return target_couple;
end;
$$;

revoke execute on function public.set_initial_question_delivery_time(time)
  from public, anon;
revoke execute on function public.schedule_question_delivery_time_update(time)
  from public, anon;
grant execute on function public.set_initial_question_delivery_time(time)
  to authenticated;
grant execute on function public.schedule_question_delivery_time_update(time)
  to authenticated;

alter table public.daily_questions
  drop constraint if exists daily_questions_story_loop_match_fkey,
  drop constraint if exists daily_questions_story_loop_unique;

drop index if exists public.daily_questions_story_loop_unique_idx;

alter table public.daily_questions
  alter column story_loop_id drop not null;

alter table public.daily_questions
  add column closed_at timestamptz;

update public.daily_questions as question
set closed_at = coalesce(question.updated_at, question.created_at, now())
where question.status = 'completed';

with ranked_questions as (
  select
    question.id,
    row_number() over (
      partition by question.couple_id
      order by
        question.assigned_date desc,
        question.created_at desc,
        question.id desc
    ) as question_rank
  from public.daily_questions as question
)
update public.daily_questions as question
set closed_at = now()
from ranked_questions as ranked
where ranked.id = question.id
  and ranked.question_rank > 1
  and question.status in ('pending', 'answered_by_one')
  and question.closed_at is null;

create unique index daily_questions_one_open_per_couple_idx
  on public.daily_questions (couple_id)
  where closed_at is null
    and status in ('pending', 'answered_by_one');

alter table public.daily_questions
  add constraint daily_questions_story_loop_match_fkey
    foreign key (couple_id, assigned_date, story_loop_id)
    references public.daily_story_loops(couple_id, couple_date, id)
    on delete set null (story_loop_id)
    not valid;

alter table public.daily_questions
  validate constraint daily_questions_story_loop_match_fkey;

update public.daily_story_loops as story_loop
set
  status = 'card_only_completed',
  question_generated_at = null
where story_loop.status = 'question_preparing'
  and not exists (
    select 1
    from public.daily_questions as question
    where question.story_loop_id = story_loop.id
  );

create index if not exists daily_questions_story_loop_id_idx
  on public.daily_questions (story_loop_id)
  where story_loop_id is not null;

alter table public.story_loop_cards
  add column is_featured boolean not null default false,
  add column retained_at timestamptz;

alter table public.story_loop_cards
  drop constraint if exists story_loop_cards_loop_author_unique;

create unique index story_loop_cards_featured_author_date_unique
  on public.story_loop_cards (couple_id, couple_date, author_user_id)
  where is_featured;

create index story_loop_cards_author_date_latest_idx
  on public.story_loop_cards (
    couple_id,
    couple_date,
    author_user_id,
    submitted_at desc,
    id desc
  );

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
  saved_card public.story_loop_cards%rowtype;
  partner_user_id uuid;
  normalized_preview_path text := btrim(requested_preview_path);
  normalized_scene_data_path text := btrim(requested_scene_data_path);
  normalized_background_image_path text := nullif(
    btrim(requested_background_image_path),
    ''
  );
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

  if expected_revision is not null then
    perform private.raise_app_error('story_card_locked');
  end if;

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

  select dsl.*
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

    select dsl.*
    into target_story_loop
    from public.daily_story_loops as dsl
    where dsl.couple_id = active_couple.id
      and dsl.couple_date = current_couple_date
    for update;
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

  if partner_user_id is not null
    and not exists (
      select 1
      from public.story_loop_notification_events as slne
      where slne.couple_id = active_couple.id
        and slne.sender_user_id = current_user_id
        and slne.receiver_user_id = partner_user_id
        and slne.event_type = 'partner_story_card_uploaded'
        and slne.created_at >= now() - interval '5 minutes'
    )
  then
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

  select dq.id
  into assigned_daily_question_id
  from public.daily_questions as dq
  where dq.couple_id = active_couple.id
    and dq.assigned_date = current_couple_date;

  return query
    select
      target_story_loop.id,
      target_story_loop.status,
      saved_card.id,
      saved_card.revision,
      false,
      assigned_daily_question_id;
end;
$$;

create or replace function public.delete_story_card(
  target_card_id uuid
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
  target_card public.story_loop_cards%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  current_couple_date := private.current_date_in_timezone(active_couple.timezone);

  select slc.*
  into target_card
  from public.story_loop_cards as slc
  where slc.id = target_card_id
    and slc.couple_id = active_couple.id
  for update;

  if not found then
    perform private.raise_app_error('story_card_not_found');
  end if;

  if target_card.author_user_id <> current_user_id then
    perform private.raise_app_error('story_card_not_owned');
  end if;

  if target_card.couple_date <> current_couple_date then
    perform private.raise_app_error('story_card_locked');
  end if;

  delete from public.story_loop_cards as slc
  where slc.id = target_card.id;

  update public.daily_story_loops as dsl
  set updated_at = now()
  where dsl.id = target_card.story_loop_id
    and not exists (
      select 1
      from public.story_loop_cards as remaining_card
      where remaining_card.story_loop_id = dsl.id
    )
    and not exists (
      select 1
      from public.daily_questions as linked_question
      where linked_question.story_loop_id = dsl.id
    );

  delete from public.daily_story_loops as dsl
  where dsl.id = target_card.story_loop_id
    and not exists (
      select 1
      from public.story_loop_cards as remaining_card
      where remaining_card.story_loop_id = dsl.id
    )
    and not exists (
      select 1
      from public.daily_questions as linked_question
      where linked_question.story_loop_id = dsl.id
    );
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
  target_card public.story_loop_cards%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if expected_revision is null or expected_revision < 1 then
    perform private.raise_app_error('story_card_revision_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  current_couple_date := private.current_date_in_timezone(active_couple.timezone);

  select slc.*
  into target_card
  from public.story_loop_cards as slc
  where slc.couple_id = active_couple.id
    and slc.couple_date = current_couple_date
    and slc.author_user_id = current_user_id
  order by slc.submitted_at desc, slc.id desc
  limit 1
  for update;

  if not found then
    perform private.raise_app_error('story_card_not_found');
  end if;

  if target_card.revision <> expected_revision then
    perform private.raise_app_error('story_card_revision_conflict');
  end if;

  perform public.delete_story_card(target_card.id);
end;
$$;

create or replace function public.set_today_story_card_featured(
  target_card_id uuid
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
  target_card public.story_loop_cards%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  current_couple_date := private.current_date_in_timezone(active_couple.timezone);

  select slc.*
  into target_card
  from public.story_loop_cards as slc
  where slc.id = target_card_id
    and slc.couple_id = active_couple.id
    and slc.couple_date = current_couple_date
  for update;

  if not found then
    perform private.raise_app_error('story_card_not_found');
  end if;

  if target_card.author_user_id <> current_user_id then
    perform private.raise_app_error('story_card_not_owned');
  end if;

  update public.story_loop_cards as slc
  set is_featured = false
  where slc.couple_id = active_couple.id
    and slc.couple_date = current_couple_date
    and slc.author_user_id = current_user_id
    and slc.is_featured;

  update public.story_loop_cards as slc
  set is_featured = true
  where slc.id = target_card.id;
end;
$$;

revoke execute on function public.delete_story_card(uuid)
  from public, anon;
revoke execute on function public.set_today_story_card_featured(uuid)
  from public, anon;
grant execute on function public.delete_story_card(uuid)
  to authenticated;
grant execute on function public.set_today_story_card_featured(uuid)
  to authenticated;

create or replace function public.get_today_story_card_stacks()
returns table (
  couple_id uuid,
  couple_date date,
  access_mode text,
  can_create_card boolean,
  author_user_id uuid,
  latest_card_id uuid,
  latest_card_preview_path text,
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
declare
  current_user_id uuid := auth.uid();
  current_couple_context record;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select *
  into current_couple_context
  from private.get_current_couple_context()
  limit 1;

  if not found then
    return;
  end if;

  if current_couple_context.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if current_couple_context.current_couple_date
    < current_couple_context.relationship_start_date
  then
    return;
  end if;

  return query
    with ranked_cards as (
      select
        slc.*,
        row_number() over (
          partition by slc.author_user_id
          order by slc.submitted_at desc, slc.id desc
        ) as cover_rank,
        count(*) over (
          partition by slc.author_user_id
        )::integer as author_card_count
      from public.story_loop_cards as slc
      where slc.couple_id = current_couple_context.id
        and slc.couple_date = current_couple_context.current_couple_date
    )
    select
      current_couple_context.id,
      current_couple_context.current_couple_date,
      current_couple_context.access_mode,
      current_couple_context.access_mode = 'active',
      ranked.author_user_id,
      ranked.id,
      ranked.preview_path,
      ranked.submitted_at,
      ranked.is_featured,
      ranked.author_card_count,
      ranked.author_user_id = current_user_id
    from ranked_cards as ranked
    where ranked.cover_rank = 1
    order by
      case when ranked.author_user_id = current_user_id then 0 else 1 end,
      ranked.author_user_id;
end;
$$;

create or replace function public.get_story_card_stack(
  target_date date,
  target_author_user_id uuid
)
returns table (
  "position" integer,
  card_id uuid,
  author_user_id uuid,
  preview_path text,
  scene_data_path text,
  has_photo boolean,
  has_drawing boolean,
  has_text boolean,
  submitted_at timestamptz,
  revision integer,
  is_featured boolean,
  can_delete boolean,
  can_feature boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_couple_context record;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select *
  into current_couple_context
  from private.get_current_couple_context()
  limit 1;

  if not found
    or target_date is null
    or target_author_user_id is null
    or current_couple_context.relationship_start_date is null
    or target_date < current_couple_context.relationship_start_date
    or target_date > current_couple_context.current_couple_date
    or (
      target_author_user_id is distinct from current_couple_context.user_a_id
      and target_author_user_id is distinct from current_couple_context.user_b_id
    )
  then
    return;
  end if;

  return query
    with visible_cards as (
      select slc.*
      from public.story_loop_cards as slc
      where slc.couple_id = current_couple_context.id
        and slc.couple_date = target_date
        and slc.author_user_id = target_author_user_id
      order by
        case
          when target_date < current_couple_context.current_couple_date
            then slc.is_featured::integer
          else 0
        end desc,
        slc.submitted_at desc,
        slc.id desc
      limit case
        when target_date < current_couple_context.current_couple_date then 1
        else 2147483647
      end
    )
    select
      row_number() over (
        order by vc.submitted_at desc, vc.id desc
      )::integer,
      vc.id,
      vc.author_user_id,
      vc.preview_path,
      vc.scene_data_path,
      vc.has_photo,
      vc.has_drawing,
      vc.has_text,
      vc.submitted_at,
      vc.revision,
      vc.is_featured,
      current_couple_context.access_mode = 'active'
        and target_date = current_couple_context.current_couple_date
        and vc.author_user_id = current_user_id,
      current_couple_context.access_mode = 'active'
        and target_date = current_couple_context.current_couple_date
        and vc.author_user_id = current_user_id
    from visible_cards as vc
    order by vc.submitted_at desc, vc.id desc;
end;
$$;

revoke execute on function public.get_today_story_card_stacks()
  from public, anon;
revoke execute on function public.get_story_card_stack(date, uuid)
  from public, anon;
grant execute on function public.get_today_story_card_stacks()
  to authenticated;
grant execute on function public.get_story_card_stack(date, uuid)
  to authenticated;

create or replace function public.finalize_expired_story_cards(
  requested_run_at timestamptz,
  requested_limit integer default 100
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_group record;
  retained_card_id uuid;
  processed_group_count integer := 0;
begin
  if requested_run_at is null
    or requested_limit is null
    or requested_limit < 1
    or requested_limit > 500
  then
    raise exception 'invalid_story_card_rollover_query';
  end if;

  for target_group in
    select
      slc.couple_id,
      slc.couple_date,
      slc.author_user_id
    from public.story_loop_cards as slc
    join public.couples as c on c.id = slc.couple_id
    where slc.couple_date
        < (requested_run_at at time zone c.timezone)::date
      and slc.retained_at is null
    group by slc.couple_id, slc.couple_date, slc.author_user_id
    order by slc.couple_date, slc.couple_id, slc.author_user_id
    limit requested_limit
  loop
    perform pg_advisory_xact_lock(
      hashtext('story_card_rollover'),
      hashtext(
        target_group.couple_id::text
          || ':'
          || target_group.couple_date::text
          || ':'
          || target_group.author_user_id::text
      )
    );

    select slc.id
    into retained_card_id
    from public.story_loop_cards as slc
    where slc.couple_id = target_group.couple_id
      and slc.couple_date = target_group.couple_date
      and slc.author_user_id = target_group.author_user_id
    order by slc.is_featured desc, slc.submitted_at desc, slc.id desc
    limit 1
    for update;

    if retained_card_id is null then
      continue;
    end if;

    update public.story_loop_cards as slc
    set retained_at = coalesce(slc.retained_at, requested_run_at)
    where slc.id = retained_card_id;

    delete from public.story_loop_cards as slc
    where slc.couple_id = target_group.couple_id
      and slc.couple_date = target_group.couple_date
      and slc.author_user_id = target_group.author_user_id
      and slc.id <> retained_card_id;

    processed_group_count := processed_group_count + 1;
  end loop;

  return processed_group_count;
end;
$$;

revoke execute on function public.finalize_expired_story_cards(
  timestamptz,
  integer
) from public, anon, authenticated;
grant execute on function public.finalize_expired_story_cards(
  timestamptz,
  integer
) to service_role;

create function private.get_open_daily_question(
  target_couple_id uuid
)
returns setof public.daily_questions
language sql
stable
security definer
set search_path = ''
as $$
  select question
  from public.daily_questions as question
  where question.couple_id = target_couple_id
    and question.closed_at is null
    and question.status in ('pending', 'answered_by_one')
  order by
    question.assigned_date desc,
    question.created_at desc,
    question.id desc
  limit 1;
$$;

create function private.get_current_daily_question(
  target_couple_id uuid,
  target_current_date date
)
returns setof public.daily_questions
language sql
stable
security definer
set search_path = ''
as $$
  select question
  from public.daily_questions as question
  where question.couple_id = target_couple_id
    and (
      (
        question.closed_at is null
        and question.status in ('pending', 'answered_by_one')
      )
      or question.assigned_date = target_current_date
    )
  order by
    case
      when question.closed_at is null
        and question.status in ('pending', 'answered_by_one')
        then 0
      else 1
    end,
    question.assigned_date desc,
    question.created_at desc,
    question.id desc
  limit 1;
$$;

revoke execute on function private.get_open_daily_question(uuid)
  from public, anon, authenticated;
revoke execute on function private.get_current_daily_question(uuid, date)
  from public, anon, authenticated;

create or replace function private.assign_due_daily_question(
  target_couple public.couples,
  target_date date
)
returns public.daily_questions
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_story_loop public.daily_story_loops%rowtype;
  target_daily_question public.daily_questions%rowtype;
  created_temporary_loop boolean := false;
begin
  perform pg_advisory_xact_lock(
    hashtext('daily_question_lifecycle'),
    hashtext(target_couple.id::text)
  );

  select open_question.*
  into target_daily_question
  from private.get_open_daily_question(target_couple.id) as open_question;

  if found then
    if target_daily_question.assigned_date = target_date then
      return target_daily_question;
    end if;

    return null;
  end if;

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id
    and dq.assigned_date = target_date
  for update;

  if found then
    return null;
  end if;

  select dsl.*
  into target_story_loop
  from public.daily_story_loops as dsl
  where dsl.couple_id = target_couple.id
    and dsl.couple_date = target_date
  for update;

  if not found then
    insert into public.daily_story_loops (
      couple_id,
      couple_date,
      status
    )
    values (
      target_couple.id,
      target_date,
      'waiting_partner_card'
    )
    on conflict on constraint daily_story_loops_couple_date_unique do nothing
    returning * into target_story_loop;

    if target_story_loop.id is null then
      select dsl.*
      into target_story_loop
      from public.daily_story_loops as dsl
      where dsl.couple_id = target_couple.id
        and dsl.couple_date = target_date
      for update;
    else
      created_temporary_loop := true;
    end if;
  end if;

  if not private.is_ai_foundation_complete(target_couple.id) then
    target_daily_question := private.assign_question_to_story_loop(
      target_couple,
      target_story_loop
    );
  else
    target_daily_question := private.assign_pending_ai_question_to_story_loop(
      target_couple,
      target_story_loop
    );

    if target_daily_question.id is null then
      target_daily_question := private.assign_curated_fallback_question_to_story_loop(
        target_couple,
        target_story_loop
      );
    end if;
  end if;

  if target_daily_question.id is null then
    if created_temporary_loop then
      delete from public.daily_story_loops as dsl
      where dsl.id = target_story_loop.id
        and not exists (
          select 1
          from public.story_loop_cards as slc
          where slc.story_loop_id = dsl.id
        );
    end if;
    return null;
  end if;

  update public.daily_questions as dq
  set story_loop_id = null
  where dq.id = target_daily_question.id
  returning dq.* into target_daily_question;

  if created_temporary_loop then
    delete from public.daily_story_loops as dsl
    where dsl.id = target_story_loop.id
      and not exists (
        select 1
        from public.story_loop_cards as slc
        where slc.story_loop_id = dsl.id
      );
  end if;

  return target_daily_question;
end;
$$;

revoke execute on function private.assign_due_daily_question(
  public.couples,
  date
) from public, anon, authenticated;

create or replace function public.assign_due_daily_questions(
  requested_run_at timestamptz,
  requested_limit integer default 100
)
returns table (
  daily_question_id uuid,
  couple_id uuid,
  receiver_user_id uuid,
  assigned_date date
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  due_couple public.couples%rowtype;
  local_date date;
  local_time time without time zone;
  target_daily_question public.daily_questions%rowtype;
begin
  if requested_run_at is null
    or requested_limit is null
    or requested_limit < 1
    or requested_limit > 200
  then
    raise exception 'invalid_daily_question_assignment_query';
  end if;

  for due_couple in
    select c.*
    from public.couples as c
    where c.status = 'active'
      and c.user_b_id is not null
      and c.relationship_start_date is not null
      and (
        c.question_delivery_time is not null
        or (
          c.next_question_delivery_time is not null
          and c.next_question_delivery_time_effective_date
            <= (requested_run_at at time zone c.timezone)::date
        )
      )
      and c.relationship_start_date
        <= (requested_run_at at time zone c.timezone)::date
      and (requested_run_at at time zone c.timezone)::time
        >= case
          when c.next_question_delivery_time_effective_date
            <= (requested_run_at at time zone c.timezone)::date
            then c.next_question_delivery_time
          else c.question_delivery_time
        end
      and not exists (
        select 1
        from public.daily_questions as open_question
        where open_question.couple_id = c.id
          and open_question.closed_at is null
          and open_question.status in ('pending', 'answered_by_one')
          and open_question.assigned_date
            < (requested_run_at at time zone c.timezone)::date
      )
      and (
        not exists (
          select 1
          from public.daily_questions as dq
          where dq.couple_id = c.id
            and dq.assigned_date
              = (requested_run_at at time zone c.timezone)::date
        )
        or exists (
          select 1
          from public.daily_questions as dq
          cross join lateral (
            values (c.user_a_id), (c.user_b_id)
          ) as member(user_id)
          where dq.couple_id = c.id
            and dq.assigned_date
              = (requested_run_at at time zone c.timezone)::date
            and dq.closed_at is null
            and dq.status in ('pending', 'answered_by_one')
            and member.user_id is not null
            and not exists (
              select 1
              from public.push_notification_dispatches as dispatch
              where dispatch.notification_type = 'daily_question_delivery'
                and dispatch.source_id = dq.id
                and dispatch.receiver_user_id = member.user_id
            )
        )
      )
    order by
      (requested_run_at at time zone c.timezone)::date,
      case
        when c.next_question_delivery_time_effective_date
          <= (requested_run_at at time zone c.timezone)::date
          then c.next_question_delivery_time
        else c.question_delivery_time
      end,
      c.id
    limit requested_limit
    for update skip locked
  loop
    perform private.apply_due_question_delivery_time(
      due_couple.id,
      requested_run_at
    );

    select c.*
    into due_couple
    from public.couples as c
    where c.id = due_couple.id
    for update;

    local_date := (requested_run_at at time zone due_couple.timezone)::date;
    local_time := (requested_run_at at time zone due_couple.timezone)::time;

    if due_couple.question_delivery_time is null
      or local_time < due_couple.question_delivery_time
    then
      continue;
    end if;

    perform pg_advisory_xact_lock(
      hashtext('daily_question_assignment'),
      hashtext(due_couple.id::text || ':' || local_date::text)
    );

    target_daily_question := private.assign_due_daily_question(
      due_couple,
      local_date
    );

    if target_daily_question.id is null then
      continue;
    end if;

    return query
      select
        target_daily_question.id,
        due_couple.id,
        member.user_id,
        target_daily_question.assigned_date
      from (
        values (due_couple.user_a_id), (due_couple.user_b_id)
      ) as member(user_id)
      where member.user_id is not null
        and not exists (
          select 1
          from public.push_notification_dispatches as dispatch
          where dispatch.notification_type = 'daily_question_delivery'
            and dispatch.source_id = target_daily_question.id
            and dispatch.receiver_user_id = member.user_id
        );
  end loop;
end;
$$;

revoke execute on function public.assign_due_daily_questions(
  timestamptz,
  integer
) from public, anon, authenticated;
grant execute on function public.assign_due_daily_questions(
  timestamptz,
  integer
) to service_role;

create or replace function private.submit_current_story_loop_question_answer(
  expected_daily_question_id uuid,
  answer_text text
)
returns table (
  daily_question_id uuid,
  status text,
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
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  current_couple_date date;
  target_daily_question public.daily_questions%rowtype;
  normalized_answer text := btrim(answer_text);
  saved_answer_count integer;
  next_status text;
  completion_time timestamptz := now();
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  select couple.*
  into active_couple
  from public.couples as couple
  where couple.id = active_couple.id
  for update;

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  current_couple_date := private.current_date_in_timezone(active_couple.timezone);

  if current_couple_date < active_couple.relationship_start_date then
    perform private.raise_app_error('question_not_ready');
  end if;

  if normalized_answer is null or char_length(normalized_answer) = 0 then
    perform private.raise_app_error('answer_required');
  end if;

  if char_length(normalized_answer) > 500 then
    perform private.raise_app_error('answer_too_long');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('daily_question_lifecycle'),
    hashtext(active_couple.id::text)
  );

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = active_couple.id
    and dq.closed_at is null
    and dq.status in ('pending', 'answered_by_one')
    and (
      expected_daily_question_id is null
      or dq.id = expected_daily_question_id
    )
  order by dq.assigned_date desc, dq.created_at desc, dq.id desc
  limit 1
  for update;

  if not found then
    perform private.raise_app_error('question_not_ready');
  end if;

  insert into public.daily_question_answers (
    daily_question_id,
    user_id,
    answer_text
  )
  values (
    target_daily_question.id,
    current_user_id,
    normalized_answer
  )
  on conflict on constraint daily_question_answers_daily_question_user_unique
  do update
    set answer_text = excluded.answer_text;

  select count(*)::integer
  into saved_answer_count
  from public.daily_question_answers as dqa
  where dqa.daily_question_id = target_daily_question.id
    and dqa.user_id in (active_couple.user_a_id, active_couple.user_b_id);

  next_status := case
    when saved_answer_count >= 2 then 'completed'
    else 'answered_by_one'
  end;

  update public.daily_questions as dq
  set
    status = next_status,
    closed_at = case
      when next_status = 'completed' then completion_time
      else null
    end
  where dq.id = target_daily_question.id
  returning dq.* into target_daily_question;

  if next_status = 'completed'
    and target_daily_question.assigned_date < current_couple_date
  then
    perform private.apply_due_question_delivery_time(
      active_couple.id,
      completion_time
    );

    select couple.*
    into active_couple
    from public.couples as couple
    where couple.id = active_couple.id
    for update;

    if active_couple.question_delivery_time is not null
      and (completion_time at time zone active_couple.timezone)::time
        >= active_couple.question_delivery_time
    then
      begin
        perform private.assign_due_daily_question(
          active_couple,
          current_couple_date
        );
      exception
        when others then
          raise warning
            'Could not assign the next daily question for couple %: %',
            active_couple.id,
            sqlerrm;
      end;
    end if;
  end if;

  return query
    select
      answer_state.daily_question_id,
      answer_state.status,
      answer_state.my_answer_id,
      answer_state.my_answer_text,
      answer_state.my_answer_answered_at,
      answer_state.my_answer_updated_at,
      answer_state.partner_answer_exists,
      answer_state.partner_answer_id,
      answer_state.partner_answer_text,
      answer_state.partner_answer_answered_at,
      answer_state.partner_answer_updated_at,
      answer_state.answer_count
    from private.get_today_question_answer_state(
      target_daily_question.id,
      current_user_id
    ) as answer_state;
end;
$$;

create or replace function public.submit_daily_question_answer(
  expected_daily_question_id uuid,
  answer_text text
)
returns table (
  daily_question_id uuid,
  status text,
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
language sql
security definer
set search_path = ''
as $$
  select *
  from private.submit_current_story_loop_question_answer(
    expected_daily_question_id,
    answer_text
  );
$$;

revoke execute on function public.submit_daily_question_answer(uuid, text)
  from public, anon;
grant execute on function public.submit_daily_question_answer(uuid, text)
  to authenticated;

create or replace function public.get_today_question_answer_state()
returns table (
  daily_question_id uuid,
  status text,
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
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  current_couple_date date;
  target_daily_question public.daily_questions%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  current_couple_date := private.current_date_in_timezone(active_couple.timezone);

  select current_question.*
  into target_daily_question
  from private.get_current_daily_question(
    active_couple.id,
    current_couple_date
  ) as current_question;

  if not found then
    return;
  end if;

  return query
    select *
    from private.get_today_question_answer_state(
      target_daily_question.id,
      current_user_id
    );
end;
$$;

create or replace function public.get_or_assign_today_question()
returns table (
  daily_question_id uuid,
  couple_id uuid,
  question_id uuid,
  question_text text,
  question_source text,
  question_category text,
  question_mood text,
  assigned_date date,
  status text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  active_couple public.couples%rowtype;
  current_couple_date date;
begin
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
      dq.id,
      dq.couple_id,
      q.id,
      q.question_text,
      q.source,
      q.category,
      q.mood,
      dq.assigned_date,
      dq.status
    from private.get_current_daily_question(
      active_couple.id,
      current_couple_date
    ) as dq
    join public.questions as q on q.id = dq.question_id;
end;
$$;

create or replace function public.get_daily_question_detail(
  target_date date default null
)
returns table (
  couple_id uuid,
  couple_date date,
  access_mode text,
  can_answer_question boolean,
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
declare
  current_user_id uuid := auth.uid();
  current_couple_context record;
  target_daily_question public.daily_questions%rowtype;
  resolved_date date;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select *
  into current_couple_context
  from private.get_current_couple_context()
  limit 1;

  if not found then
    return;
  end if;

  if current_couple_context.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if target_date is null then
    select current_question.*
    into target_daily_question
    from private.get_current_daily_question(
      current_couple_context.id,
      current_couple_context.current_couple_date
    ) as current_question;

    if not found then
      return;
    end if;

    resolved_date := target_daily_question.assigned_date;
  else
    resolved_date := target_date;
  end if;

  if resolved_date < current_couple_context.relationship_start_date
    or resolved_date > current_couple_context.current_couple_date
  then
    return;
  end if;

  return query
    select
      dq.couple_id,
      dq.assigned_date,
      current_couple_context.access_mode,
      current_couple_context.access_mode = 'active'
        and dq.closed_at is null
        and dq.status in ('pending', 'answered_by_one')
        and coalesce(answer_state.answer_count, 0) < 2,
      dq.id,
      q.id,
      q.question_text,
      q.source,
      q.category,
      q.mood,
      coalesce(answer_state.status, dq.status),
      answer_state.my_answer_id,
      answer_state.my_answer_text,
      answer_state.my_answer_answered_at,
      answer_state.my_answer_updated_at,
      coalesce(answer_state.partner_answer_exists, false),
      answer_state.partner_answer_id,
      answer_state.partner_answer_text,
      answer_state.partner_answer_answered_at,
      answer_state.partner_answer_updated_at,
      coalesce(answer_state.answer_count, 0)
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    left join lateral private.get_today_question_answer_state(
      dq.id,
      current_user_id
    ) as answer_state on true
    where dq.couple_id = current_couple_context.id
      and dq.assigned_date = resolved_date
    limit 1;
end;
$$;

revoke execute on function public.get_daily_question_detail(date)
  from public, anon;
grant execute on function public.get_daily_question_detail(date)
  to authenticated;

drop function public.get_due_unanswered_question_reminders(
  timestamptz,
  integer
);

create function public.get_due_unanswered_question_reminders(
  requested_run_at timestamptz,
  requested_limit integer default 100
)
returns table (
  daily_question_id uuid,
  couple_id uuid,
  receiver_user_id uuid,
  assigned_date date
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if requested_run_at is null
    or requested_limit is null
    or requested_limit < 1
    or requested_limit > 200
  then
    raise exception 'invalid_unanswered_reminder_query';
  end if;

  return query
    with eligible_questions as (
      select
        question.id as daily_question_id,
        question.couple_id,
        question.assigned_date,
        couple.user_a_id,
        couple.user_b_id,
        coalesce(story_loop.question_generated_at, question.created_at)
          as question_exposed_at
      from public.daily_questions as question
      join public.couples as couple
        on couple.id = question.couple_id
        and couple.status = 'active'
      left join public.daily_story_loops as story_loop
        on story_loop.id = question.story_loop_id
      where question.status in ('pending', 'answered_by_one')
        and question.closed_at is null
        and coalesce(story_loop.question_generated_at, question.created_at)
          <= requested_run_at - interval '60 minutes'
        and coalesce(story_loop.question_generated_at, question.created_at)
          >= requested_run_at - interval '24 hours'
    ),
    recipient_candidates as (
      select
        eligible.daily_question_id,
        eligible.couple_id,
        member.user_id as receiver_user_id,
        eligible.assigned_date,
        eligible.question_exposed_at
      from eligible_questions as eligible
      cross join lateral (
        values (eligible.user_a_id), (eligible.user_b_id)
      ) as member(user_id)
    )
    select
      candidate.daily_question_id,
      candidate.couple_id,
      candidate.receiver_user_id,
      candidate.assigned_date
    from recipient_candidates as candidate
    left join public.user_notification_preferences as preference
      on preference.user_id = candidate.receiver_user_id
    where coalesce(preference.reminder_enabled, true)
      and not exists (
        select 1
        from public.daily_question_answers as answer
        where answer.daily_question_id = candidate.daily_question_id
          and answer.user_id = candidate.receiver_user_id
      )
      and not exists (
        select 1
        from public.push_notification_dispatches as dispatch
        where dispatch.notification_type = 'unanswered_reminder'
          and dispatch.source_id = candidate.daily_question_id
          and dispatch.receiver_user_id = candidate.receiver_user_id
      )
    order by
      candidate.question_exposed_at,
      candidate.daily_question_id,
      candidate.receiver_user_id
    limit requested_limit;
end;
$$;

revoke execute on function public.get_due_unanswered_question_reminders(
  timestamptz,
  integer
) from public, anon, authenticated;
grant execute on function public.get_due_unanswered_question_reminders(
  timestamptz,
  integer
) to service_role;

create or replace function private.get_story_loop_detail_row(
  target_couple_id uuid,
  target_couple_date date,
  requested_user_id uuid,
  requested_access_mode text,
  requested_current_couple_date date
)
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
  first_card_has_photo boolean,
  first_card_has_drawing boolean,
  first_card_has_text boolean,
  first_card_submitted_at timestamptz,
  first_card_revision integer,
  second_card_id uuid,
  second_card_author_user_id uuid,
  second_card_preview_path text,
  second_card_scene_data_path text,
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
language sql
stable
security definer
set search_path = ''
as $$
  with target_loop as (
    select
      dsl.id,
      dsl.status
    from public.daily_story_loops as dsl
    where dsl.couple_id = target_couple_id
      and dsl.couple_date = target_couple_date
    limit 1
  ),
  ranked_author_cards as (
    select
      slc.*,
      row_number() over (
        partition by slc.author_user_id
        order by
          case
            when target_couple_date < requested_current_couple_date
              then slc.is_featured::integer
            else 0
          end desc,
          slc.submitted_at desc,
          slc.id desc
      ) as author_rank
    from public.story_loop_cards as slc
    where slc.couple_id = target_couple_id
      and slc.couple_date = target_couple_date
  ),
  ordered_cards as (
    select
      ranked.id,
      ranked.author_user_id,
      ranked.preview_path,
      ranked.scene_data_path,
      ranked.has_photo,
      ranked.has_drawing,
      ranked.has_text,
      ranked.submitted_at,
      ranked.revision,
      row_number() over (
        order by ranked.submitted_at asc, ranked.id asc
      ) as card_position
    from ranked_author_cards as ranked
    where ranked.author_rank = 1
  ),
  card_count_state as (
    select count(*)::integer as card_count
    from ordered_cards
  ),
  first_card as (
    select *
    from ordered_cards
    where card_position = 1
  ),
  second_card as (
    select *
    from ordered_cards
    where card_position = 2
  ),
  target_question as (
    select
      dq.id as daily_question_id,
      dq.question_id,
      dq.status as question_status,
      dq.closed_at as question_closed_at,
      q.question_text,
      q.source as question_source,
      q.category as question_category,
      q.mood as question_mood
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.couple_id = target_couple_id
      and dq.assigned_date = target_couple_date
    limit 1
  )
  select
    target_couple_id,
    target_couple_date,
    requested_access_mode,
    tl.id,
    tl.status,
    false,
    requested_access_mode = 'active'
      and target_couple_date = requested_current_couple_date,
    requested_access_mode = 'active'
      and tq.daily_question_id is not null
      and tq.question_closed_at is null
      and tq.question_status in ('pending', 'answered_by_one')
      and coalesce(qas.answer_count, 0) < 2,
    coalesce(ccs.card_count, 0),
    fc.id,
    fc.author_user_id,
    fc.preview_path,
    fc.scene_data_path,
    fc.has_photo,
    fc.has_drawing,
    fc.has_text,
    fc.submitted_at,
    fc.revision,
    sc.id,
    sc.author_user_id,
    sc.preview_path,
    sc.scene_data_path,
    sc.has_photo,
    sc.has_drawing,
    sc.has_text,
    sc.submitted_at,
    sc.revision,
    tq.daily_question_id,
    tq.question_id,
    tq.question_text,
    tq.question_source,
    tq.question_category,
    tq.question_mood,
    coalesce(qas.status, tq.question_status),
    qas.my_answer_id,
    qas.my_answer_text,
    qas.my_answer_answered_at,
    qas.my_answer_updated_at,
    coalesce(qas.partner_answer_exists, false),
    qas.partner_answer_id,
    qas.partner_answer_text,
    qas.partner_answer_answered_at,
    qas.partner_answer_updated_at,
    coalesce(qas.answer_count, 0)
  from (select 1 as anchor) as base
  left join target_loop as tl on true
  left join card_count_state as ccs on true
  left join first_card as fc on true
  left join second_card as sc on true
  left join target_question as tq on true
  left join lateral private.get_today_question_answer_state(
    tq.daily_question_id,
    requested_user_id
  ) as qas on tq.daily_question_id is not null;
$$;

create or replace function public.get_story_loop_month_summary(
  target_month date
)
returns table (
  couple_date date,
  loop_status text,
  card_count integer,
  first_card_id uuid,
  first_card_author_user_id uuid,
  first_card_preview_path text,
  first_card_submitted_at timestamptz,
  second_card_id uuid,
  second_card_author_user_id uuid,
  second_card_preview_path text,
  second_card_submitted_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_couple_context record;
  month_start date;
  month_end date;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select *
  into current_couple_context
  from private.get_current_couple_context()
  limit 1;

  if not found then
    return;
  end if;

  if current_couple_context.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if target_month is null then
    return;
  end if;

  month_start := date_trunc('month', target_month::timestamp)::date;
  month_end := (month_start + interval '1 month' - interval '1 day')::date;

  if month_start > date_trunc(
    'month',
    current_couple_context.current_couple_date::timestamp
  )::date
    or month_end < current_couple_context.relationship_start_date
  then
    return;
  end if;

  return query
    with ranked_author_cards as (
      select
        slc.*,
        dsl.status as resolved_loop_status,
        row_number() over (
          partition by slc.couple_date, slc.author_user_id
          order by
            case
              when slc.couple_date < current_couple_context.current_couple_date
                then slc.is_featured::integer
              else 0
            end desc,
            slc.submitted_at desc,
            slc.id desc
        ) as author_rank
      from public.story_loop_cards as slc
      join public.daily_story_loops as dsl on dsl.id = slc.story_loop_id
      where slc.couple_id = current_couple_context.id
        and slc.couple_date between greatest(
          month_start,
          current_couple_context.relationship_start_date
        ) and least(
          month_end,
          current_couple_context.current_couple_date
        )
    ),
    ordered_cards as (
      select
        ranked.couple_date,
        ranked.resolved_loop_status,
        ranked.id,
        ranked.author_user_id,
        ranked.preview_path,
        ranked.submitted_at,
        row_number() over (
          partition by ranked.couple_date
          order by ranked.submitted_at asc, ranked.id asc
        ) as card_position,
        count(*) over (
          partition by ranked.couple_date
        )::integer as day_card_count
      from ranked_author_cards as ranked
      where ranked.author_rank = 1
    ),
    day_states as (
      select distinct
        oc.couple_date,
        oc.resolved_loop_status,
        oc.day_card_count
      from ordered_cards as oc
    ),
    first_cards as (
      select *
      from ordered_cards
      where card_position = 1
    ),
    second_cards as (
      select *
      from ordered_cards
      where card_position = 2
    )
    select
      ds.couple_date,
      ds.resolved_loop_status,
      ds.day_card_count,
      fc.id,
      fc.author_user_id,
      fc.preview_path,
      fc.submitted_at,
      sc.id,
      sc.author_user_id,
      sc.preview_path,
      sc.submitted_at
    from day_states as ds
    left join first_cards as fc on fc.couple_date = ds.couple_date
    left join second_cards as sc on sc.couple_date = ds.couple_date
    order by ds.couple_date;
end;
$$;

revoke execute on function private.get_story_loop_detail_row(
  uuid,
  date,
  uuid,
  text,
  date
) from public, anon, authenticated;

comment on column public.couples.question_delivery_time is
  'Shared local time when the daily question becomes available.';
comment on column public.couples.next_question_delivery_time is
  'Pending shared delivery time applied on the effective local date.';
comment on column public.daily_questions.closed_at is
  'Timestamp when a question stopped being the current answerable question.';
comment on column public.story_loop_cards.is_featured is
  'Explicit retention choice for one card per author and couple date.';
comment on column public.story_loop_cards.retained_at is
  'Timestamp when rollover retained this card and removed its siblings.';
