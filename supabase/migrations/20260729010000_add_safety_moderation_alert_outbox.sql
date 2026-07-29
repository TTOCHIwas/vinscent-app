create table public.safety_moderation_alerts (
  report_id uuid primary key
    references public.safety_reports(id) on delete cascade,
  status text not null default 'pending',
  attempt_count integer not null default 0,
  max_attempts integer not null default 5,
  available_at timestamptz not null default now(),
  claim_token uuid,
  claimed_by text,
  claimed_at timestamptz,
  delivered_at timestamptz,
  completed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint safety_moderation_alerts_status_check
    check (
      status in (
        'pending',
        'processing',
        'delivered',
        'failed',
        'cancelled'
      )
    ),
  constraint safety_moderation_alerts_attempt_count_check
    check (attempt_count between 0 and max_attempts),
  constraint safety_moderation_alerts_max_attempts_check
    check (max_attempts between 1 and 10),
  constraint safety_moderation_alerts_claimed_by_check
    check (
      claimed_by is null
      or char_length(claimed_by) between 1 and 120
    ),
  constraint safety_moderation_alerts_last_error_check
    check (
      last_error is null
      or char_length(last_error) between 1 and 2000
    ),
  constraint safety_moderation_alerts_processing_state_check
    check (
      status <> 'processing'
      or (
        claim_token is not null
        and claimed_by is not null
        and claimed_at is not null
      )
    )
);

create index safety_moderation_alerts_claim_idx
  on public.safety_moderation_alerts (
    status,
    available_at,
    created_at,
    report_id
  )
  where status in ('pending', 'processing');

create index safety_moderation_alerts_stale_claim_idx
  on public.safety_moderation_alerts (claimed_at, report_id)
  where status = 'processing';

alter table public.safety_moderation_alerts enable row level security;

create trigger safety_moderation_alerts_set_updated_at
  before update on public.safety_moderation_alerts
  for each row
  execute function public.set_updated_at();

revoke all on table public.safety_moderation_alerts
  from public, anon, authenticated;
grant all on table public.safety_moderation_alerts to service_role;

create or replace function private.sync_safety_moderation_alert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  should_enqueue boolean := false;
begin
  if tg_op = 'INSERT' then
    should_enqueue := new.status = 'pending';
  elsif new.status = 'pending' then
    should_enqueue :=
      old.status <> 'pending'
      or new.reported_user_id is distinct from old.reported_user_id
      or new.couple_id is distinct from old.couple_id
      or new.reason is distinct from old.reason
      or new.details is distinct from old.details
      or new.content_snapshot is distinct from old.content_snapshot;
  end if;

  if should_enqueue then
    insert into public.safety_moderation_alerts (report_id)
    values (new.id)
    on conflict (report_id)
    do update
    set
      status = 'pending',
      attempt_count = 0,
      available_at = now(),
      claim_token = null,
      claimed_by = null,
      claimed_at = null,
      delivered_at = null,
      completed_at = null,
      last_error = null;
  elsif tg_op = 'UPDATE'
    and old.status = 'pending'
    and new.status <> 'pending'
  then
    update public.safety_moderation_alerts
    set
      status = 'cancelled',
      claim_token = null,
      claimed_by = null,
      claimed_at = null,
      completed_at = now()
    where report_id = new.id
      and status <> 'delivered';
  end if;

  return new;
end;
$$;

revoke all on function private.sync_safety_moderation_alert()
  from public, anon, authenticated;

create trigger safety_reports_sync_moderation_alert
  after insert or update on public.safety_reports
  for each row
  execute function private.sync_safety_moderation_alert();

insert into public.safety_moderation_alerts (
  report_id,
  available_at,
  created_at,
  updated_at
)
select
  report.id,
  now(),
  report.created_at,
  now()
from public.safety_reports as report
where report.status = 'pending'
on conflict (report_id) do nothing;

create or replace function public.claim_safety_moderation_alerts(
  requested_worker_id text,
  requested_limit integer default 20
)
returns table (
  report_id uuid,
  claim_token uuid,
  attempt_count integer,
  max_attempts integer,
  reporter_user_id uuid,
  reported_user_id uuid,
  couple_id uuid,
  target_type text,
  target_id text,
  reason text,
  details text,
  content_snapshot text,
  report_created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_worker_id text := nullif(btrim(requested_worker_id), '');
  stale_claimed_before timestamptz := now() - interval '5 minutes';
begin
  if normalized_worker_id is null
    or char_length(normalized_worker_id) > 120
  then
    perform private.raise_app_error('invalid_moderation_worker_id');
  end if;

  if requested_limit is null
    or requested_limit < 1
    or requested_limit > 100
  then
    perform private.raise_app_error('invalid_moderation_claim_limit');
  end if;

  update public.safety_moderation_alerts as alert
  set
    status = 'failed',
    claim_token = null,
    claimed_by = null,
    claimed_at = null,
    completed_at = now(),
    last_error = coalesce(
      alert.last_error,
      'moderation_alert_abandoned_after_final_attempt'
    )
  where alert.status = 'processing'
    and alert.claimed_at < stale_claimed_before
    and alert.attempt_count >= alert.max_attempts;

  return query
  with candidates as (
    select alert.report_id
    from public.safety_moderation_alerts as alert
    join public.safety_reports as report
      on report.id = alert.report_id
    where report.status = 'pending'
      and alert.attempt_count < alert.max_attempts
      and (
        (
          alert.status = 'pending'
          and alert.available_at <= now()
        )
        or (
          alert.status = 'processing'
          and alert.claimed_at < stale_claimed_before
        )
      )
    order by alert.available_at, alert.created_at, alert.report_id
    for update of alert skip locked
    limit requested_limit
  ),
  claimed as (
    update public.safety_moderation_alerts as alert
    set
      status = 'processing',
      attempt_count = alert.attempt_count + 1,
      claim_token = gen_random_uuid(),
      claimed_by = normalized_worker_id,
      claimed_at = now(),
      completed_at = null,
      last_error = null
    from candidates
    where alert.report_id = candidates.report_id
    returning alert.*
  )
  select
    claimed.report_id,
    claimed.claim_token,
    claimed.attempt_count,
    claimed.max_attempts,
    report.reporter_user_id,
    report.reported_user_id,
    report.couple_id,
    report.target_type,
    report.target_id,
    report.reason,
    report.details,
    report.content_snapshot,
    report.created_at
  from claimed
  join public.safety_reports as report
    on report.id = claimed.report_id
  order by claimed.created_at, claimed.report_id;
end;
$$;

create or replace function public.complete_safety_moderation_alert(
  requested_report_id uuid,
  requested_claim_token uuid,
  requested_delivered boolean,
  requested_error text default null,
  requested_retry_delay_seconds integer default 60
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_error text := nullif(btrim(requested_error), '');
  claimed_alert public.safety_moderation_alerts%rowtype;
  next_status text;
begin
  if requested_report_id is null or requested_claim_token is null then
    perform private.raise_app_error('invalid_moderation_alert_claim');
  end if;

  if requested_delivered is null then
    perform private.raise_app_error('invalid_moderation_alert_result');
  end if;

  if requested_retry_delay_seconds is null
    or requested_retry_delay_seconds < 0
    or requested_retry_delay_seconds > 3600
  then
    perform private.raise_app_error('invalid_moderation_retry_delay');
  end if;

  if normalized_error is not null and char_length(normalized_error) > 2000 then
    perform private.raise_app_error('moderation_alert_error_too_long');
  end if;

  if not requested_delivered and normalized_error is null then
    perform private.raise_app_error('moderation_alert_error_required');
  end if;

  select alert.*
  into claimed_alert
  from public.safety_moderation_alerts as alert
  where alert.report_id = requested_report_id
    and alert.status = 'processing'
    and alert.claim_token = requested_claim_token
  for update;

  if not found then
    return 'stale';
  end if;

  if requested_delivered then
    next_status := 'delivered';

    update public.safety_moderation_alerts
    set
      status = next_status,
      claim_token = null,
      claimed_by = null,
      claimed_at = null,
      delivered_at = now(),
      completed_at = now(),
      last_error = null
    where report_id = claimed_alert.report_id;
  elsif claimed_alert.attempt_count >= claimed_alert.max_attempts then
    next_status := 'failed';

    update public.safety_moderation_alerts
    set
      status = next_status,
      claim_token = null,
      claimed_by = null,
      claimed_at = null,
      completed_at = now(),
      last_error = normalized_error
    where report_id = claimed_alert.report_id;
  else
    next_status := 'pending';

    update public.safety_moderation_alerts
    set
      status = next_status,
      available_at =
        now() + make_interval(secs => requested_retry_delay_seconds),
      claim_token = null,
      claimed_by = null,
      claimed_at = null,
      completed_at = null,
      last_error = normalized_error
    where report_id = claimed_alert.report_id;
  end if;

  return next_status;
end;
$$;

revoke execute on function public.claim_safety_moderation_alerts(
  text,
  integer
) from public, anon, authenticated;
revoke execute on function public.complete_safety_moderation_alert(
  uuid,
  uuid,
  boolean,
  text,
  integer
) from public, anon, authenticated;

grant execute on function public.claim_safety_moderation_alerts(
  text,
  integer
) to service_role;
grant execute on function public.complete_safety_moderation_alert(
  uuid,
  uuid,
  boolean,
  text,
  integer
) to service_role;
