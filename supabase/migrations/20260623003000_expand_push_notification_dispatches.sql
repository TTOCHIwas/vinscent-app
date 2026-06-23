alter table public.push_notification_dispatches
  add column if not exists receiver_user_id uuid references auth.users(id) on delete cascade;

update public.push_notification_dispatches as pnd
set receiver_user_id = ce.receiver_user_id
from public.couple_expressions as ce
where pnd.notification_type = 'couple_expression'
  and pnd.source_id = ce.id
  and pnd.receiver_user_id is null;

delete from public.push_notification_dispatches
where receiver_user_id is null;

alter table public.push_notification_dispatches
  alter column receiver_user_id set not null;

alter table public.push_notification_dispatches
  drop constraint if exists push_notification_dispatches_pkey;

alter table public.push_notification_dispatches
  add primary key (notification_type, source_id, receiver_user_id);

create index if not exists push_notification_dispatches_receiver_status_claimed_idx
  on public.push_notification_dispatches (
    receiver_user_id,
    status,
    claimed_at
  );

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
      'couple_disconnect'
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
      'couple_disconnect'
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
    'couple_disconnect'
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

create or replace function public.claim_push_notification_dispatch(
  requested_notification_type text,
  requested_source_id uuid
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
  resolved_receiver_user_id uuid;
begin
  if normalized_notification_type = 'couple_expression' then
    select ce.receiver_user_id
    into resolved_receiver_user_id
    from public.couple_expressions as ce
    where ce.id = requested_source_id;
  end if;

  if resolved_receiver_user_id is null then
    raise exception 'invalid_notification_receiver';
  end if;

  return query
    select *
    from public.claim_push_notification_dispatch(
      normalized_notification_type,
      requested_source_id,
      resolved_receiver_user_id
    );
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
    'couple_disconnect'
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

create or replace function public.complete_push_notification_dispatch(
  requested_notification_type text,
  requested_source_id uuid,
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
  resolved_receiver_user_id uuid;
begin
  if normalized_notification_type = 'couple_expression' then
    select ce.receiver_user_id
    into resolved_receiver_user_id
    from public.couple_expressions as ce
    where ce.id = requested_source_id;
  end if;

  if resolved_receiver_user_id is null then
    raise exception 'invalid_notification_receiver';
  end if;

  perform public.complete_push_notification_dispatch(
    normalized_notification_type,
    requested_source_id,
    resolved_receiver_user_id,
    requested_status,
    requested_error_message
  );
end;
$$;

revoke execute on function public.claim_push_notification_dispatch(text, uuid)
  from public, anon, authenticated;
revoke execute on function public.claim_push_notification_dispatch(text, uuid, uuid)
  from public, anon, authenticated;
revoke execute on function public.complete_push_notification_dispatch(
  text,
  uuid,
  text,
  text
)
  from public, anon, authenticated;
revoke execute on function public.complete_push_notification_dispatch(
  text,
  uuid,
  uuid,
  text,
  text
)
  from public, anon, authenticated;

grant execute on function public.claim_push_notification_dispatch(text, uuid)
  to service_role;
grant execute on function public.claim_push_notification_dispatch(text, uuid, uuid)
  to service_role;
grant execute on function public.complete_push_notification_dispatch(
  text,
  uuid,
  text,
  text
)
  to service_role;
grant execute on function public.complete_push_notification_dispatch(
  text,
  uuid,
  uuid,
  text,
  text
)
  to service_role;
