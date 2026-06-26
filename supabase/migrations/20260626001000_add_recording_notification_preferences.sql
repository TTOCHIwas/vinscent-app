alter table public.user_notification_preferences
  add column if not exists recording_enabled boolean not null default true;

drop function if exists public.get_my_notification_preferences();

create function public.get_my_notification_preferences()
returns table (
  user_id uuid,
  expression_enabled boolean,
  partner_answer_enabled boolean,
  daily_question_enabled boolean,
  reminder_enabled boolean,
  couple_disconnect_enabled boolean,
  recording_enabled boolean,
  daily_question_delivery_time time,
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

  insert into public.user_notification_preferences (user_id)
  values (current_user_id)
  on conflict (user_id) do nothing;

  return query
    select
      unp.user_id,
      unp.expression_enabled,
      unp.partner_answer_enabled,
      unp.daily_question_enabled,
      unp.reminder_enabled,
      unp.couple_disconnect_enabled,
      unp.recording_enabled,
      unp.daily_question_delivery_time,
      unp.created_at,
      unp.updated_at
    from public.user_notification_preferences as unp
    where unp.user_id = current_user_id;
end;
$$;

drop function if exists public.update_my_notification_preferences(
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  time
);

create function public.update_my_notification_preferences(
  requested_expression_enabled boolean,
  requested_partner_answer_enabled boolean,
  requested_daily_question_enabled boolean,
  requested_reminder_enabled boolean,
  requested_couple_disconnect_enabled boolean,
  requested_recording_enabled boolean,
  requested_daily_question_delivery_time time
)
returns table (
  user_id uuid,
  expression_enabled boolean,
  partner_answer_enabled boolean,
  daily_question_enabled boolean,
  reminder_enabled boolean,
  couple_disconnect_enabled boolean,
  recording_enabled boolean,
  daily_question_delivery_time time,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_delivery_time time := requested_daily_question_delivery_time;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if normalized_delivery_time is null then
    perform private.raise_app_error('invalid_delivery_time');
  end if;

  insert into public.user_notification_preferences (
    user_id,
    expression_enabled,
    partner_answer_enabled,
    daily_question_enabled,
    reminder_enabled,
    couple_disconnect_enabled,
    recording_enabled,
    daily_question_delivery_time
  )
  values (
    current_user_id,
    coalesce(requested_expression_enabled, true),
    coalesce(requested_partner_answer_enabled, true),
    coalesce(requested_daily_question_enabled, true),
    coalesce(requested_reminder_enabled, true),
    coalesce(requested_couple_disconnect_enabled, true),
    coalesce(requested_recording_enabled, true),
    normalized_delivery_time
  )
  on conflict (user_id)
  do update
    set
      expression_enabled = coalesce(
        requested_expression_enabled,
        public.user_notification_preferences.expression_enabled
      ),
      partner_answer_enabled = coalesce(
        requested_partner_answer_enabled,
        public.user_notification_preferences.partner_answer_enabled
      ),
      daily_question_enabled = coalesce(
        requested_daily_question_enabled,
        public.user_notification_preferences.daily_question_enabled
      ),
      reminder_enabled = coalesce(
        requested_reminder_enabled,
        public.user_notification_preferences.reminder_enabled
      ),
      couple_disconnect_enabled = coalesce(
        requested_couple_disconnect_enabled,
        public.user_notification_preferences.couple_disconnect_enabled
      ),
      recording_enabled = coalesce(
        requested_recording_enabled,
        public.user_notification_preferences.recording_enabled
      ),
      daily_question_delivery_time = normalized_delivery_time
  returning
    public.user_notification_preferences.user_id,
    public.user_notification_preferences.expression_enabled,
    public.user_notification_preferences.partner_answer_enabled,
    public.user_notification_preferences.daily_question_enabled,
    public.user_notification_preferences.reminder_enabled,
    public.user_notification_preferences.couple_disconnect_enabled,
    public.user_notification_preferences.recording_enabled,
    public.user_notification_preferences.daily_question_delivery_time,
    public.user_notification_preferences.created_at,
    public.user_notification_preferences.updated_at
  into
    user_id,
    expression_enabled,
    partner_answer_enabled,
    daily_question_enabled,
    reminder_enabled,
    couple_disconnect_enabled,
    recording_enabled,
    daily_question_delivery_time,
    created_at,
    updated_at;

  return next;
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
  boolean,
  time
)
  from public, anon;

grant execute on function public.get_my_notification_preferences()
  to authenticated;
grant execute on function public.update_my_notification_preferences(
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  time
)
  to authenticated;

alter table public.push_notification_dispatches
  drop constraint if exists push_notification_dispatches_notification_type_check;

alter table public.push_notification_dispatches
  add constraint push_notification_dispatches_notification_type_check
  check (
    notification_type in (
      'couple_expression',
      'partner_answer_completed',
      'daily_question_delivery',
      'unanswered_reminder',
      'couple_disconnect',
      'recording_activity'
    )
  );

alter table public.push_notification_deliveries
  drop constraint if exists push_notification_deliveries_notification_type_check;

alter table public.push_notification_deliveries
  add constraint push_notification_deliveries_notification_type_check
  check (
    notification_type in (
      'couple_expression',
      'partner_answer_completed',
      'daily_question_delivery',
      'unanswered_reminder',
      'couple_disconnect',
      'recording_activity'
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
    'couple_expression',
    'partner_answer_completed',
    'daily_question_delivery',
    'unanswered_reminder',
    'couple_disconnect',
    'recording_activity'
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
  returning *
  into claimed_dispatch;

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
  returning *
  into claimed_dispatch;

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
    'couple_expression',
    'partner_answer_completed',
    'daily_question_delivery',
    'unanswered_reminder',
    'couple_disconnect',
    'recording_activity'
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
