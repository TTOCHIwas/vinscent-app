drop function if exists public.send_couple_expression(text);
drop function if exists public.get_couple_expression_summary_for_date(date);

drop function if exists public.claim_push_notification_dispatch(text, uuid);
drop function if exists public.complete_push_notification_dispatch(
  text,
  uuid,
  text,
  text
);

drop function if exists public.get_my_notification_preferences();
drop function if exists public.update_my_notification_preferences(
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean
);

delete from public.push_notification_deliveries
where notification_type = 'couple_expression';

delete from public.push_notification_dispatches
where notification_type = 'couple_expression';

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
      'question_generated'
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
      'question_generated'
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
    'question_generated'
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
    'question_generated'
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

alter table public.user_notification_preferences
  drop column if exists expression_enabled;

create function public.get_my_notification_preferences()
returns table (
  user_id uuid,
  partner_answer_enabled boolean,
  daily_question_enabled boolean,
  reminder_enabled boolean,
  couple_disconnect_enabled boolean,
  recording_enabled boolean,
  partner_story_card_enabled boolean,
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

  ensured_preferences := private.ensure_user_notification_preferences(current_user_id);

  return query
    select
      ensured_preferences.user_id,
      ensured_preferences.partner_answer_enabled,
      ensured_preferences.daily_question_enabled,
      ensured_preferences.reminder_enabled,
      ensured_preferences.couple_disconnect_enabled,
      ensured_preferences.recording_enabled,
      ensured_preferences.partner_story_card_enabled,
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
  requested_partner_story_card_enabled boolean
)
returns table (
  user_id uuid,
  partner_answer_enabled boolean,
  daily_question_enabled boolean,
  reminder_enabled boolean,
  couple_disconnect_enabled boolean,
  recording_enabled boolean,
  partner_story_card_enabled boolean,
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
      unp.created_at,
      unp.updated_at;
end;
$$;

revoke execute on function public.get_my_notification_preferences()
  from public, anon;
revoke execute on function public.update_my_notification_preferences(
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
  boolean
) to authenticated;

drop table if exists public.couple_expressions;
