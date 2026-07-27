alter table public.push_notification_dispatches
  add column if not exists title text not null default '',
  add column if not exists body text not null default '',
  add column if not exists data jsonb not null default '{}'::jsonb,
  add column if not exists preference_column text,
  add column if not exists attempt_count integer not null default 1,
  add column if not exists max_attempts integer not null default 1,
  add column if not exists available_at timestamptz not null default now();

alter table public.push_notification_dispatches
  alter column max_attempts set default 5;

alter table public.push_notification_dispatches
  drop constraint if exists push_notification_dispatches_data_check,
  drop constraint if exists push_notification_dispatches_preference_column_check,
  drop constraint if exists push_notification_dispatches_attempt_count_check,
  drop constraint if exists push_notification_dispatches_max_attempts_check,
  drop constraint if exists push_notification_dispatches_attempt_limit_check;

alter table public.push_notification_dispatches
  add constraint push_notification_dispatches_data_check
    check (jsonb_typeof(data) = 'object'),
  add constraint push_notification_dispatches_preference_column_check
    check (
      preference_column is null
      or preference_column in (
        'partner_answer_enabled',
        'daily_question_enabled',
        'reminder_enabled',
        'couple_disconnect_enabled',
        'recording_enabled',
        'partner_story_card_enabled',
        'couple_activity_enabled',
        'ai_updates_enabled'
      )
    ),
  add constraint push_notification_dispatches_attempt_count_check
    check (attempt_count >= 1),
  add constraint push_notification_dispatches_max_attempts_check
    check (max_attempts between 1 and 10),
  add constraint push_notification_dispatches_attempt_limit_check
    check (attempt_count <= max_attempts);

create index if not exists push_notification_dispatches_retry_idx
  on public.push_notification_dispatches (available_at, created_at)
  where status = 'failed';

drop function if exists public.claim_push_notification_dispatch(
  text,
  uuid,
  uuid
);

create function public.claim_push_notification_dispatch(
  requested_notification_type text,
  requested_source_id uuid,
  requested_receiver_user_id uuid,
  requested_title text default '',
  requested_body text default '',
  requested_data jsonb default '{}'::jsonb,
  requested_preference_column text default null,
  requested_max_attempts integer default 1
)
returns table (
  claim_result text,
  notification_type text,
  source_id uuid,
  receiver_user_id uuid,
  claim_token uuid,
  dispatch_status text,
  claimed_at timestamptz,
  attempt_count integer,
  max_attempts integer,
  available_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_notification_type text := btrim(requested_notification_type);
  normalized_title text := coalesce(requested_title, '');
  normalized_body text := coalesce(requested_body, '');
  normalized_preference_column text :=
    nullif(btrim(requested_preference_column), '');
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
    'ai_update',
    'calendar_event_reminder'
  ) then
    raise exception 'invalid_notification_type';
  end if;

  if requested_source_id is null then
    raise exception 'invalid_notification_source';
  end if;

  if requested_receiver_user_id is null then
    raise exception 'invalid_notification_receiver';
  end if;

  if requested_data is null or jsonb_typeof(requested_data) <> 'object' then
    raise exception 'invalid_notification_data';
  end if;

  if normalized_preference_column is not null
    and normalized_preference_column not in (
      'partner_answer_enabled',
      'daily_question_enabled',
      'reminder_enabled',
      'couple_disconnect_enabled',
      'recording_enabled',
      'partner_story_card_enabled',
      'couple_activity_enabled',
      'ai_updates_enabled'
    )
  then
    raise exception 'invalid_notification_preference';
  end if;

  if requested_max_attempts is null
    or requested_max_attempts < 1
    or requested_max_attempts > 10
  then
    raise exception 'invalid_notification_max_attempts';
  end if;

  insert into public.push_notification_dispatches (
    notification_type,
    source_id,
    receiver_user_id,
    status,
    claimed_at,
    title,
    body,
    data,
    preference_column,
    attempt_count,
    max_attempts,
    available_at
  )
  values (
    normalized_notification_type,
    requested_source_id,
    requested_receiver_user_id,
    'processing',
    now(),
    normalized_title,
    normalized_body,
    requested_data,
    normalized_preference_column,
    1,
    requested_max_attempts,
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
        claimed_dispatch.claim_token,
        claimed_dispatch.status,
        claimed_dispatch.claimed_at,
        claimed_dispatch.attempt_count,
        claimed_dispatch.max_attempts,
        claimed_dispatch.available_at;
    return;
  end if;

  update public.push_notification_dispatches as dispatch
  set
    status = 'processing',
    claim_token = gen_random_uuid(),
    claimed_at = now(),
    completed_at = null,
    error_message = null,
    attempt_count = dispatch.attempt_count + 1,
    available_at = now()
  where dispatch.notification_type = normalized_notification_type
    and dispatch.source_id = requested_source_id
    and dispatch.receiver_user_id = requested_receiver_user_id
    and dispatch.attempt_count < dispatch.max_attempts
    and (
      (
        dispatch.status = 'processing'
        and dispatch.claimed_at < stale_claimed_before
      )
      or (
        dispatch.status = 'failed'
        and dispatch.available_at <= now()
      )
    )
  returning * into claimed_dispatch;

  if found then
    return query
      select
        'claimed'::text,
        claimed_dispatch.notification_type,
        claimed_dispatch.source_id,
        claimed_dispatch.receiver_user_id,
        claimed_dispatch.claim_token,
        claimed_dispatch.status,
        claimed_dispatch.claimed_at,
        claimed_dispatch.attempt_count,
        claimed_dispatch.max_attempts,
        claimed_dispatch.available_at;
    return;
  end if;

  select *
  into claimed_dispatch
  from public.push_notification_dispatches as dispatch
  where dispatch.notification_type = normalized_notification_type
    and dispatch.source_id = requested_source_id
    and dispatch.receiver_user_id = requested_receiver_user_id;

  return query
    select
      'duplicate'::text,
      claimed_dispatch.notification_type,
      claimed_dispatch.source_id,
      claimed_dispatch.receiver_user_id,
      claimed_dispatch.claim_token,
      claimed_dispatch.status,
      claimed_dispatch.claimed_at,
      claimed_dispatch.attempt_count,
      claimed_dispatch.max_attempts,
      claimed_dispatch.available_at;
end;
$$;

drop function if exists public.complete_push_notification_delivery(
  text,
  uuid,
  uuid,
  uuid,
  integer,
  integer,
  integer,
  text,
  text
);

create function public.complete_push_notification_delivery(
  requested_notification_type text,
  requested_source_id uuid,
  requested_receiver_user_id uuid,
  requested_claim_token uuid,
  requested_target_token_count integer,
  requested_success_count integer,
  requested_failure_count integer,
  requested_status text,
  requested_error_message text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_notification_type text := btrim(requested_notification_type);
  normalized_status text := btrim(requested_status);
  normalized_error_message text := nullif(btrim(requested_error_message), '');
  current_dispatch public.push_notification_dispatches%rowtype;
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
    'ai_update',
    'calendar_event_reminder'
  ) then
    raise exception 'invalid_notification_type';
  end if;

  if requested_source_id is null then
    raise exception 'invalid_notification_source';
  end if;

  if requested_receiver_user_id is null then
    raise exception 'invalid_notification_receiver';
  end if;

  if requested_claim_token is null then
    raise exception 'invalid_dispatch_claim_token';
  end if;

  if normalized_status not in (
    'sent',
    'partial_failure',
    'failed',
    'skipped'
  ) then
    raise exception 'invalid_dispatch_status';
  end if;

  if requested_target_token_count < 0
    or requested_success_count < 0
    or requested_failure_count < 0
    or requested_target_token_count
      <> requested_success_count + requested_failure_count
  then
    raise exception 'invalid_delivery_counts';
  end if;

  select *
  into current_dispatch
  from public.push_notification_dispatches as dispatch
  where dispatch.notification_type = normalized_notification_type
    and dispatch.source_id = requested_source_id
    and dispatch.receiver_user_id = requested_receiver_user_id
  for update;

  if not found then
    raise exception 'dispatch_missing';
  end if;

  if current_dispatch.claim_token <> requested_claim_token then
    raise exception 'dispatch_claim_lost';
  end if;

  if current_dispatch.status <> 'processing' then
    if current_dispatch.status = normalized_status
      and exists (
        select 1
        from public.push_notification_deliveries as delivery
        where delivery.notification_type = normalized_notification_type
          and delivery.source_id = requested_source_id
          and delivery.receiver_user_id = requested_receiver_user_id
          and delivery.target_token_count = requested_target_token_count
          and delivery.success_count = requested_success_count
          and delivery.failure_count = requested_failure_count
          and delivery.status = normalized_status
          and delivery.error_message is not distinct
            from normalized_error_message
      )
    then
      return 'duplicate';
    end if;

    raise exception 'dispatch_completion_conflict';
  end if;

  insert into public.push_notification_deliveries (
    notification_type,
    source_id,
    receiver_user_id,
    target_token_count,
    success_count,
    failure_count,
    status,
    error_message
  )
  values (
    normalized_notification_type,
    requested_source_id,
    requested_receiver_user_id,
    requested_target_token_count,
    requested_success_count,
    requested_failure_count,
    normalized_status,
    normalized_error_message
  );

  update public.push_notification_dispatches as dispatch
  set
    status = normalized_status,
    completed_at = now(),
    error_message = normalized_error_message,
    available_at = case
      when normalized_status = 'failed'
        and dispatch.attempt_count < dispatch.max_attempts
      then now() + make_interval(
        secs => least(
          900,
          (
            15 * power(
              2::numeric,
              greatest(dispatch.attempt_count - 1, 0)
            )
          )::integer
        )
      )
      else now()
    end
  where dispatch.notification_type = normalized_notification_type
    and dispatch.source_id = requested_source_id
    and dispatch.receiver_user_id = requested_receiver_user_id
    and dispatch.claim_token = requested_claim_token
    and dispatch.status = 'processing';

  return 'completed';
end;
$$;

create function public.get_retryable_push_notification_dispatches(
  requested_limit integer default 100
)
returns table (
  notification_type text,
  source_id uuid,
  receiver_user_id uuid,
  title text,
  body text,
  data jsonb,
  preference_column text,
  attempt_count integer,
  max_attempts integer,
  available_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if requested_limit is null
    or requested_limit < 1
    or requested_limit > 200
  then
    raise exception 'invalid_retry_dispatch_limit';
  end if;

  return query
    select
      dispatch.notification_type,
      dispatch.source_id,
      dispatch.receiver_user_id,
      dispatch.title,
      dispatch.body,
      dispatch.data,
      dispatch.preference_column,
      dispatch.attempt_count,
      dispatch.max_attempts,
      dispatch.available_at
    from public.push_notification_dispatches as dispatch
    where dispatch.attempt_count < dispatch.max_attempts
      and (
        (
          dispatch.status = 'failed'
          and dispatch.available_at <= now()
        )
        or (
          dispatch.status = 'processing'
          and dispatch.claimed_at < now() - interval '5 minutes'
        )
      )
    order by dispatch.available_at, dispatch.created_at
    limit requested_limit;
end;
$$;

revoke execute on function public.claim_push_notification_dispatch(
  text,
  uuid,
  uuid,
  text,
  text,
  jsonb,
  text,
  integer
) from public, anon, authenticated;
revoke execute on function public.complete_push_notification_delivery(
  text,
  uuid,
  uuid,
  uuid,
  integer,
  integer,
  integer,
  text,
  text
) from public, anon, authenticated;
revoke execute on function public.get_retryable_push_notification_dispatches(
  integer
) from public, anon, authenticated;

grant execute on function public.claim_push_notification_dispatch(
  text,
  uuid,
  uuid,
  text,
  text,
  jsonb,
  text,
  integer
) to service_role;
grant execute on function public.complete_push_notification_delivery(
  text,
  uuid,
  uuid,
  uuid,
  integer,
  integer,
  integer,
  text,
  text
) to service_role;
grant execute on function public.get_retryable_push_notification_dispatches(
  integer
) to service_role;
