alter table public.push_notification_dispatches
  add column claim_token uuid not null default gen_random_uuid();

drop function if exists public.claim_push_notification_dispatch(
  text,
  uuid,
  uuid
);

create function public.claim_push_notification_dispatch(
  requested_notification_type text,
  requested_source_id uuid,
  requested_receiver_user_id uuid
)
returns table (
  claim_result text,
  notification_type text,
  source_id uuid,
  receiver_user_id uuid,
  claim_token uuid,
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
        claimed_dispatch.claim_token,
        claimed_dispatch.status,
        claimed_dispatch.claimed_at;
    return;
  end if;

  update public.push_notification_dispatches as pnd
  set
    status = 'processing',
    claim_token = gen_random_uuid(),
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
        claimed_dispatch.claim_token,
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
      claimed_dispatch.claim_token,
      claimed_dispatch.status,
      claimed_dispatch.claimed_at;
end;
$$;

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
  from public.push_notification_dispatches as pnd
  where pnd.notification_type = normalized_notification_type
    and pnd.source_id = requested_source_id
    and pnd.receiver_user_id = requested_receiver_user_id
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
        from public.push_notification_deliveries as pnd
        where pnd.notification_type = normalized_notification_type
          and pnd.source_id = requested_source_id
          and pnd.receiver_user_id = requested_receiver_user_id
          and pnd.target_token_count = requested_target_token_count
          and pnd.success_count = requested_success_count
          and pnd.failure_count = requested_failure_count
          and pnd.status = normalized_status
          and pnd.error_message is not distinct from normalized_error_message
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

  update public.push_notification_dispatches as pnd
  set
    status = normalized_status,
    completed_at = now(),
    error_message = normalized_error_message
  where pnd.notification_type = normalized_notification_type
    and pnd.source_id = requested_source_id
    and pnd.receiver_user_id = requested_receiver_user_id
    and pnd.claim_token = requested_claim_token
    and pnd.status = 'processing';

  return 'completed';
end;
$$;

revoke execute on function public.claim_push_notification_dispatch(
  text,
  uuid,
  uuid
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

grant execute on function public.claim_push_notification_dispatch(
  text,
  uuid,
  uuid
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
