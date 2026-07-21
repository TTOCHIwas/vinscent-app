alter table public.user_notification_preferences
  add column couple_activity_enabled boolean not null default true,
  add column ai_updates_enabled boolean not null default true;

create table public.app_notification_events (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  sender_user_id uuid references auth.users(id) on delete set null,
  receiver_user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null,
  daily_question_id uuid
    references public.daily_questions(id) on delete set null,
  curriculum_version integer
    references public.ai_question_curricula(version) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  deduplication_key text not null unique,
  created_at timestamptz not null default now(),

  constraint app_notification_events_type_check
    check (
      event_type in (
        'couple_setup_started',
        'couple_setup_completed',
        'couple_character_updated',
        'couple_reconnected',
        'ai_feedback_ready',
        'ai_memory_review_ready',
        'ai_personalization_activated'
      )
    ),
  constraint app_notification_events_distinct_users_check
    check (sender_user_id is null or sender_user_id <> receiver_user_id),
  constraint app_notification_events_payload_check
    check (jsonb_typeof(payload) = 'object'),
  constraint app_notification_events_deduplication_key_check
    check (char_length(btrim(deduplication_key)) between 1 and 400)
);

create index app_notification_events_receiver_created_idx
  on public.app_notification_events (receiver_user_id, created_at desc);

create index app_notification_events_couple_created_idx
  on public.app_notification_events (couple_id, created_at desc);

alter table public.app_notification_events enable row level security;

revoke all on table public.app_notification_events
  from public, anon, authenticated;
grant select on table public.app_notification_events to service_role;

create or replace function private.emit_app_notification_event(
  target_couple_id uuid,
  target_sender_user_id uuid,
  target_receiver_user_id uuid,
  target_event_type text,
  target_daily_question_id uuid,
  target_curriculum_version integer,
  target_payload jsonb,
  target_deduplication_key text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if target_couple_id is null
    or target_receiver_user_id is null
    or target_event_type is null
    or target_deduplication_key is null
    or target_sender_user_id = target_receiver_user_id
  then
    return;
  end if;

  insert into public.app_notification_events (
    couple_id,
    sender_user_id,
    receiver_user_id,
    event_type,
    daily_question_id,
    curriculum_version,
    payload,
    deduplication_key
  )
  values (
    target_couple_id,
    target_sender_user_id,
    target_receiver_user_id,
    target_event_type,
    target_daily_question_id,
    target_curriculum_version,
    coalesce(target_payload, '{}'::jsonb),
    btrim(target_deduplication_key)
  )
  on conflict (deduplication_key) do nothing;
end;
$$;

create or replace function private.notify_couple_activity_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  reconnect_receiver_user_id uuid;
begin
  if old.status = 'pending'
    and new.status = 'active'
    and new.user_b_id is not null
  then
    perform private.emit_app_notification_event(
      new.id,
      new.user_b_id,
      new.user_a_id,
      'couple_setup_started',
      null,
      null,
      '{}'::jsonb,
      'couple_setup_started:' || new.id::text
    );
  end if;

  if old.status = 'disconnected'
    and new.status = 'active'
    and current_user_id in (new.user_a_id, new.user_b_id)
  then
    reconnect_receiver_user_id := case
      when current_user_id = new.user_a_id then new.user_b_id
      else new.user_a_id
    end;

    perform private.emit_app_notification_event(
      new.id,
      current_user_id,
      reconnect_receiver_user_id,
      'couple_reconnected',
      null,
      null,
      '{}'::jsonb,
      'couple_reconnected:' || new.id::text || ':'
        || new.connected_at::text
    );
  end if;

  if old.character_setup_status = 'pending'
    and new.character_setup_status in ('custom', 'default')
    and new.user_b_id is not null
  then
    perform private.emit_app_notification_event(
      new.id,
      new.user_b_id,
      new.user_a_id,
      'couple_setup_completed',
      null,
      null,
      jsonb_build_object(
        'character_setup_status',
        new.character_setup_status
      ),
      'couple_setup_completed:' || new.id::text
    );
  end if;

  return new;
end;
$$;

create trigger couples_notify_activity_change
  after update of status, character_setup_status on public.couples
  for each row
  execute function private.notify_couple_activity_change();

create or replace function private.notify_couple_character_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_couple public.couples%rowtype;
  receiver_user_id uuid;
begin
  select c.*
  into target_couple
  from public.couples as c
  where c.id = new.couple_id;

  if not found
    or target_couple.status <> 'active'
    or target_couple.character_setup_status = 'pending'
    or new.updated_by is null
    or new.updated_by not in (
      target_couple.user_a_id,
      target_couple.user_b_id
    )
  then
    return new;
  end if;

  receiver_user_id := case
    when new.updated_by = target_couple.user_a_id
      then target_couple.user_b_id
    else target_couple.user_a_id
  end;

  perform private.emit_app_notification_event(
    new.couple_id,
    new.updated_by,
    receiver_user_id,
    'couple_character_updated',
    null,
    null,
    '{}'::jsonb,
    'couple_character_updated:' || new.couple_id::text || ':'
      || txid_current()::text
  );

  return new;
end;
$$;

create trigger couple_characters_notify_change
  after insert or update on public.couple_characters
  for each row
  execute function private.notify_couple_character_change();

create or replace function private.notify_ai_feedback_ready()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_couple public.couples%rowtype;
  assigned_date date;
  should_notify boolean;
  receiver_user_id uuid;
begin
  should_notify := new.state = 'published'
    and new.safety_status = 'passed';

  if tg_op = 'UPDATE' then
    should_notify := should_notify and (
      old.state is distinct from new.state
      or old.safety_status is distinct from new.safety_status
      or old.source_run_id is distinct from new.source_run_id
    );
  end if;

  if not should_notify then
    return new;
  end if;

  select c.*
  into target_couple
  from public.couples as c
  where c.id = new.couple_id
    and c.status = 'active'
    and c.user_b_id is not null;

  if not found then
    return new;
  end if;

  select dq.assigned_date
  into assigned_date
  from public.daily_questions as dq
  where dq.id = new.daily_question_id;

  foreach receiver_user_id in array array[
    target_couple.user_a_id,
    target_couple.user_b_id
  ]
  loop
    perform private.emit_app_notification_event(
      new.couple_id,
      null,
      receiver_user_id,
      'ai_feedback_ready',
      new.daily_question_id,
      null,
      jsonb_build_object('assigned_date', assigned_date),
      'ai_feedback_ready:' || new.daily_question_id::text || ':'
        || receiver_user_id::text
    );
  end loop;

  return new;
end;
$$;

create trigger ai_question_feedbacks_notify_ready
  after insert or update of state, safety_status, source_run_id
  on public.ai_question_feedbacks
  for each row
  execute function private.notify_ai_feedback_ready();

create or replace function private.emit_ai_memory_review_notifications(
  target_couple_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_couple public.couples%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  completed_count integer;
  receiver_user_id uuid;
begin
  select c.*
  into target_couple
  from public.couples as c
  where c.id = target_couple_id
    and c.status = 'active'
    and c.user_b_id is not null;

  if not found
    or not private.have_all_couple_members_granted_ai_consent(
      target_couple_id
    )
  then
    return;
  end if;

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if not found then
    return;
  end if;

  select count(distinct dq.question_id)::integer
  into completed_count
  from public.daily_questions as dq
  join public.questions as q on q.id = dq.question_id
  where dq.couple_id = target_couple_id
    and dq.status = 'completed'
    and q.curriculum_version = active_curriculum.version;

  if completed_count < active_curriculum.question_count
    or not private.is_ai_foundation_processing_complete(
      target_couple_id,
      active_curriculum.version
    )
  then
    return;
  end if;

  foreach receiver_user_id in array array[
    target_couple.user_a_id,
    target_couple.user_b_id
  ]
  loop
    if exists (
      select 1
      from public.ai_memories as aim
      where aim.couple_id = target_couple_id
        and aim.origin_curriculum_version = active_curriculum.version
        and aim.state = 'pending'
        and private.is_ai_memory_review_eligible(aim.id)
        and (
          (
            aim.scope = 'personal'
            and aim.subject_user_id = receiver_user_id
          )
          or (
            aim.scope = 'couple'
            and not exists (
              select 1
              from public.ai_memory_confirmations as aimc
              where aimc.memory_id = aim.id
                and aimc.user_id = receiver_user_id
            )
          )
        )
    ) then
      perform private.emit_app_notification_event(
        target_couple_id,
        null,
        receiver_user_id,
        'ai_memory_review_ready',
        null,
        active_curriculum.version,
        '{}'::jsonb,
        'ai_memory_review_ready:' || target_couple_id::text || ':'
          || active_curriculum.version::text || ':'
          || receiver_user_id::text
      );
    end if;
  end loop;
end;
$$;

create or replace function private.notify_ai_memory_review_from_job()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.job_type = 'extract_memories'
    and new.status = 'succeeded'
    and (
      tg_op = 'INSERT'
      or old.status is distinct from new.status
    )
  then
    perform private.emit_ai_memory_review_notifications(new.couple_id);
  end if;

  return new;
end;
$$;

create trigger ai_processing_jobs_notify_memory_review
  after insert or update of status on public.ai_processing_jobs
  for each row
  execute function private.notify_ai_memory_review_from_job();

create or replace function private.notify_ai_memory_review_from_memory()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.emit_ai_memory_review_notifications(new.couple_id);
  return new;
end;
$$;

create trigger ai_memories_notify_review_ready
  after insert or update of
    state,
    learning_domain,
    evidence_type,
    origin_curriculum_version
  on public.ai_memories
  for each row
  execute function private.notify_ai_memory_review_from_memory();

create or replace function private.notify_ai_personalization_activated()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_couple public.couples%rowtype;
  receiver_user_id uuid;
begin
  select c.*
  into target_couple
  from public.couples as c
  where c.id = new.couple_id
    and c.status = 'active'
    and c.user_b_id is not null;

  if not found then
    return new;
  end if;

  foreach receiver_user_id in array array[
    target_couple.user_a_id,
    target_couple.user_b_id
  ]
  loop
    perform private.emit_app_notification_event(
      new.couple_id,
      null,
      receiver_user_id,
      'ai_personalization_activated',
      null,
      new.curriculum_version,
      '{}'::jsonb,
      'ai_personalization_activated:' || new.couple_id::text || ':'
        || new.curriculum_version::text || ':' || receiver_user_id::text
    );
  end loop;

  return new;
end;
$$;

create trigger ai_personalization_states_notify_activated
  after insert on public.ai_personalization_states
  for each row
  execute function private.notify_ai_personalization_activated();

alter table public.push_notification_dispatches
  drop constraint if exists push_notification_dispatches_notification_type_check;

alter table public.push_notification_dispatches
  add constraint push_notification_dispatches_notification_type_check
  check (
    notification_type in (
      'partner_answer_completed',
      'daily_question_delivery',
      'unanswered_reminder',
      'couple_disconnect',
      'recording_activity',
      'partner_story_card_uploaded',
      'question_generated',
      'couple_activity',
      'ai_update'
    )
  );

alter table public.push_notification_deliveries
  drop constraint if exists push_notification_deliveries_notification_type_check;

alter table public.push_notification_deliveries
  add constraint push_notification_deliveries_notification_type_check
  check (
    notification_type in (
      'partner_answer_completed',
      'daily_question_delivery',
      'unanswered_reminder',
      'couple_disconnect',
      'recording_activity',
      'partner_story_card_uploaded',
      'question_generated',
      'couple_activity',
      'ai_update'
    )
  );

create or replace function public.claim_push_notification_dispatch(
  requested_notification_type text,
  requested_source_id uuid,
  requested_receiver_user_id uuid
)
returns table (
  claim_result text,
  notification_type text,
  source_id uuid,
  receiver_user_id uuid,
  dispatch_status text,
  claimed_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_notification_type text := btrim(requested_notification_type);
  stale_claimed_before timestamptz := now() - interval '5 minutes';
  claimed_dispatch public.push_notification_dispatches%rowtype;
begin
  if normalized_notification_type not in (
    'partner_answer_completed',
    'daily_question_delivery',
    'unanswered_reminder',
    'couple_disconnect',
    'recording_activity',
    'partner_story_card_uploaded',
    'question_generated',
    'couple_activity',
    'ai_update'
  ) then
    raise exception 'invalid_notification_type';
  end if;

  if requested_source_id is null then
    raise exception 'invalid_notification_source';
  end if;

  if requested_receiver_user_id is null then
    raise exception 'invalid_notification_receiver';
  end if;

  insert into public.push_notification_dispatches (
    notification_type,
    source_id,
    receiver_user_id,
    status,
    claimed_at
  )
  values (
    normalized_notification_type,
    requested_source_id,
    requested_receiver_user_id,
    'processing',
    now()
  )
  on conflict do nothing
  returning * into claimed_dispatch;

  if found then
    return query
      select
        'claimed'::text,
        claimed_dispatch.notification_type,
        claimed_dispatch.source_id,
        claimed_dispatch.receiver_user_id,
        claimed_dispatch.status,
        claimed_dispatch.claimed_at;
    return;
  end if;

  update public.push_notification_dispatches as pnd
  set
    status = 'processing',
    claimed_at = now(),
    completed_at = null,
    error_message = null
  where pnd.notification_type = normalized_notification_type
    and pnd.source_id = requested_source_id
    and pnd.receiver_user_id = requested_receiver_user_id
    and pnd.status = 'processing'
    and pnd.claimed_at < stale_claimed_before
  returning * into claimed_dispatch;

  if found then
    return query
      select
        'claimed'::text,
        claimed_dispatch.notification_type,
        claimed_dispatch.source_id,
        claimed_dispatch.receiver_user_id,
        claimed_dispatch.status,
        claimed_dispatch.claimed_at;
    return;
  end if;

  select *
  into claimed_dispatch
  from public.push_notification_dispatches as pnd
  where pnd.notification_type = normalized_notification_type
    and pnd.source_id = requested_source_id
    and pnd.receiver_user_id = requested_receiver_user_id;

  return query
    select
      'duplicate'::text,
      claimed_dispatch.notification_type,
      claimed_dispatch.source_id,
      claimed_dispatch.receiver_user_id,
      claimed_dispatch.status,
      claimed_dispatch.claimed_at;
end;
$$;

create or replace function public.complete_push_notification_dispatch(
  requested_notification_type text,
  requested_source_id uuid,
  requested_receiver_user_id uuid,
  requested_status text,
  requested_error_message text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_notification_type text := btrim(requested_notification_type);
  normalized_status text := btrim(requested_status);
  normalized_error_message text := nullif(btrim(requested_error_message), '');
begin
  if normalized_notification_type not in (
    'partner_answer_completed',
    'daily_question_delivery',
    'unanswered_reminder',
    'couple_disconnect',
    'recording_activity',
    'partner_story_card_uploaded',
    'question_generated',
    'couple_activity',
    'ai_update'
  ) then
    raise exception 'invalid_notification_type';
  end if;

  if requested_source_id is null then
    raise exception 'invalid_notification_source';
  end if;

  if requested_receiver_user_id is null then
    raise exception 'invalid_notification_receiver';
  end if;

  if normalized_status not in (
    'sent',
    'partial_failure',
    'failed',
    'skipped'
  ) then
    raise exception 'invalid_dispatch_status';
  end if;

  update public.push_notification_dispatches as pnd
  set
    status = normalized_status,
    completed_at = now(),
    error_message = normalized_error_message
  where pnd.notification_type = normalized_notification_type
    and pnd.source_id = requested_source_id
    and pnd.receiver_user_id = requested_receiver_user_id;
end;
$$;

drop function if exists public.get_my_notification_preferences();
drop function if exists public.update_my_notification_preferences(
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean
);

create function public.get_my_notification_preferences()
returns table (
  user_id uuid,
  partner_answer_enabled boolean,
  daily_question_enabled boolean,
  reminder_enabled boolean,
  couple_disconnect_enabled boolean,
  recording_enabled boolean,
  partner_story_card_enabled boolean,
  couple_activity_enabled boolean,
  ai_updates_enabled boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  ensured_preferences public.user_notification_preferences%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  ensured_preferences := private.ensure_user_notification_preferences(
    current_user_id
  );

  return query
    select
      ensured_preferences.user_id,
      ensured_preferences.partner_answer_enabled,
      ensured_preferences.daily_question_enabled,
      ensured_preferences.reminder_enabled,
      ensured_preferences.couple_disconnect_enabled,
      ensured_preferences.recording_enabled,
      ensured_preferences.partner_story_card_enabled,
      ensured_preferences.couple_activity_enabled,
      ensured_preferences.ai_updates_enabled,
      ensured_preferences.created_at,
      ensured_preferences.updated_at;
end;
$$;

create function public.update_my_notification_preferences(
  requested_partner_answer_enabled boolean,
  requested_daily_question_enabled boolean,
  requested_reminder_enabled boolean,
  requested_couple_disconnect_enabled boolean,
  requested_recording_enabled boolean,
  requested_partner_story_card_enabled boolean,
  requested_couple_activity_enabled boolean,
  requested_ai_updates_enabled boolean
)
returns table (
  user_id uuid,
  partner_answer_enabled boolean,
  daily_question_enabled boolean,
  reminder_enabled boolean,
  couple_disconnect_enabled boolean,
  recording_enabled boolean,
  partner_story_card_enabled boolean,
  couple_activity_enabled boolean,
  ai_updates_enabled boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  perform private.ensure_user_notification_preferences(current_user_id);

  return query
    update public.user_notification_preferences as unp
    set
      partner_answer_enabled = coalesce(
        requested_partner_answer_enabled,
        unp.partner_answer_enabled
      ),
      daily_question_enabled = coalesce(
        requested_daily_question_enabled,
        unp.daily_question_enabled
      ),
      reminder_enabled = coalesce(
        requested_reminder_enabled,
        unp.reminder_enabled
      ),
      couple_disconnect_enabled = coalesce(
        requested_couple_disconnect_enabled,
        unp.couple_disconnect_enabled
      ),
      recording_enabled = coalesce(
        requested_recording_enabled,
        unp.recording_enabled
      ),
      partner_story_card_enabled = coalesce(
        requested_partner_story_card_enabled,
        unp.partner_story_card_enabled
      ),
      couple_activity_enabled = coalesce(
        requested_couple_activity_enabled,
        unp.couple_activity_enabled
      ),
      ai_updates_enabled = coalesce(
        requested_ai_updates_enabled,
        unp.ai_updates_enabled
      )
    where unp.user_id = current_user_id
    returning
      unp.user_id,
      unp.partner_answer_enabled,
      unp.daily_question_enabled,
      unp.reminder_enabled,
      unp.couple_disconnect_enabled,
      unp.recording_enabled,
      unp.partner_story_card_enabled,
      unp.couple_activity_enabled,
      unp.ai_updates_enabled,
      unp.created_at,
      unp.updated_at;
end;
$$;

revoke execute on function private.emit_app_notification_event(
  uuid,
  uuid,
  uuid,
  text,
  uuid,
  integer,
  jsonb,
  text
) from public, anon, authenticated;
revoke execute on function private.emit_ai_memory_review_notifications(uuid)
  from public, anon, authenticated;
revoke execute on function public.get_my_notification_preferences()
  from public, anon;
revoke execute on function public.update_my_notification_preferences(
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean
) from public, anon;

grant execute on function public.get_my_notification_preferences()
  to authenticated;
grant execute on function public.update_my_notification_preferences(
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean
) to authenticated;
grant execute on function public.claim_push_notification_dispatch(
  text,
  uuid,
  uuid
) to service_role;
grant execute on function public.complete_push_notification_dispatch(
  text,
  uuid,
  uuid,
  text,
  text
) to service_role;
