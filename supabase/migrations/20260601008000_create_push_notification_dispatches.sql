create table public.push_notification_dispatches (
  notification_type text not null,
  source_id uuid not null,
  status text not null default 'processing',
  claimed_at timestamptz not null default now(),
  completed_at timestamptz,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (notification_type, source_id),
  constraint push_notification_dispatches_notification_type_check
    check (notification_type in ('couple_expression')),
  constraint push_notification_dispatches_status_check
    check (status in (
      'processing',
      'sent',
      'partial_failure',
      'failed',
      'skipped'
    ))
);

create index push_notification_dispatches_status_claimed_idx
  on public.push_notification_dispatches (status, claimed_at);

alter table public.push_notification_dispatches enable row level security;

create trigger push_notification_dispatches_set_updated_at
  before update on public.push_notification_dispatches
  for each row
  execute function public.set_updated_at();

create or replace function public.claim_push_notification_dispatch(
  requested_notification_type text,
  requested_source_id uuid
)
returns table (
  claim_result text,
  notification_type text,
  source_id uuid,
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
  if normalized_notification_type not in ('couple_expression') then
    raise exception 'invalid_notification_type';
  end if;

  if requested_source_id is null then
    raise exception 'invalid_notification_source';
  end if;

  insert into public.push_notification_dispatches (
    notification_type,
    source_id,
    status,
    claimed_at
  )
  values (
    normalized_notification_type,
    requested_source_id,
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
        claimed_dispatch.status,
        claimed_dispatch.claimed_at;

    return;
  end if;

  select *
  into claimed_dispatch
  from public.push_notification_dispatches as pnd
  where pnd.notification_type = normalized_notification_type
    and pnd.source_id = requested_source_id;

  return query
    select
      'duplicate'::text,
      claimed_dispatch.notification_type,
      claimed_dispatch.source_id,
      claimed_dispatch.status,
      claimed_dispatch.claimed_at;
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
  normalized_status text := btrim(requested_status);
  normalized_error_message text := nullif(btrim(requested_error_message), '');
begin
  if normalized_notification_type not in ('couple_expression') then
    raise exception 'invalid_notification_type';
  end if;

  if requested_source_id is null then
    raise exception 'invalid_notification_source';
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
    and pnd.source_id = requested_source_id;
end;
$$;

revoke execute on function public.claim_push_notification_dispatch(text, uuid)
  from public, anon, authenticated;
revoke execute on function public.complete_push_notification_dispatch(
  text,
  uuid,
  text,
  text
)
  from public, anon, authenticated;

grant execute on function public.claim_push_notification_dispatch(text, uuid)
  to service_role;
grant execute on function public.complete_push_notification_dispatch(
  text,
  uuid,
  text,
  text
)
  to service_role;
