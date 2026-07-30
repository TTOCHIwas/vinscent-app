create table public.storage_cleanup_health_state (
  monitor_key text primary key,
  status text not null,
  issue_signature text not null default '',
  issue_codes text[] not null default '{}'::text[],
  incident_id uuid,
  incident_started_at timestamptz,
  failed_request_count integer not null default 0,
  stale_processing_count integer not null default 0,
  overdue_pending_count integer not null default 0,
  cleanup_cron_status text not null,
  cleanup_cron_last_succeeded_at timestamptz,
  last_evaluated_at timestamptz not null default now(),
  last_changed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint storage_cleanup_health_state_monitor_key_check
    check (monitor_key = 'storage_cleanup'),
  constraint storage_cleanup_health_state_status_check
    check (status in ('healthy', 'degraded')),
  constraint storage_cleanup_health_state_issue_signature_check
    check (
      char_length(issue_signature) <= 500
      and issue_signature = array_to_string(issue_codes, ',')
    ),
  constraint storage_cleanup_health_state_incident_check
    check (
      (
        status = 'healthy'
        and incident_id is null
        and incident_started_at is null
        and cardinality(issue_codes) = 0
      )
      or (
        status = 'degraded'
        and incident_id is not null
        and incident_started_at is not null
        and cardinality(issue_codes) > 0
      )
    ),
  constraint storage_cleanup_health_state_counts_check
    check (
      failed_request_count >= 0
      and stale_processing_count >= 0
      and overdue_pending_count >= 0
    ),
  constraint storage_cleanup_health_state_cron_status_check
    check (
      cleanup_cron_status in (
        'healthy',
        'missing',
        'duplicate',
        'inactive',
        'schedule_mismatch',
        'never_succeeded',
        'stale'
      )
    )
);

alter table public.storage_cleanup_health_state enable row level security;

create trigger storage_cleanup_health_state_set_updated_at
  before update on public.storage_cleanup_health_state
  for each row
  execute function public.set_updated_at();

revoke all on table public.storage_cleanup_health_state
  from public, anon, authenticated;
grant all on table public.storage_cleanup_health_state to service_role;

create table public.storage_cleanup_operational_alerts (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null,
  alert_kind text not null,
  issue_signature text not null,
  issue_codes text[] not null,
  failed_request_count integer not null,
  stale_processing_count integer not null,
  overdue_pending_count integer not null,
  cleanup_cron_status text not null,
  cleanup_cron_last_succeeded_at timestamptz,
  detected_at timestamptz not null,
  incident_started_at timestamptz not null,
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

  constraint storage_cleanup_operational_alerts_kind_check
    check (alert_kind in ('degraded', 'recovered')),
  constraint storage_cleanup_operational_alerts_issue_signature_check
    check (
      char_length(issue_signature) between 1 and 500
      and cardinality(issue_codes) > 0
      and issue_signature = array_to_string(issue_codes, ',')
    ),
  constraint storage_cleanup_operational_alerts_counts_check
    check (
      failed_request_count >= 0
      and stale_processing_count >= 0
      and overdue_pending_count >= 0
    ),
  constraint storage_cleanup_operational_alerts_cron_status_check
    check (
      cleanup_cron_status in (
        'healthy',
        'missing',
        'duplicate',
        'inactive',
        'schedule_mismatch',
        'never_succeeded',
        'stale'
      )
    ),
  constraint storage_cleanup_operational_alerts_status_check
    check (
      status in (
        'pending',
        'processing',
        'delivered',
        'failed'
      )
    ),
  constraint storage_cleanup_operational_alerts_attempt_count_check
    check (attempt_count between 0 and max_attempts),
  constraint storage_cleanup_operational_alerts_max_attempts_check
    check (max_attempts between 1 and 10),
  constraint storage_cleanup_operational_alerts_claimed_by_check
    check (
      claimed_by is null
      or char_length(claimed_by) between 1 and 120
    ),
  constraint storage_cleanup_operational_alerts_last_error_check
    check (
      last_error is null
      or char_length(last_error) between 1 and 2000
    ),
  constraint storage_cleanup_operational_alerts_processing_state_check
    check (
      status <> 'processing'
      or (
        claim_token is not null
        and claimed_by is not null
        and claimed_at is not null
      )
    ),
  constraint storage_cleanup_operational_alerts_transition_unique
    unique (incident_id, alert_kind, issue_signature)
);

create index storage_cleanup_operational_alerts_claim_idx
  on public.storage_cleanup_operational_alerts (
    status,
    available_at,
    created_at,
    id
  )
  where status in ('pending', 'processing');

create index storage_cleanup_operational_alerts_stale_claim_idx
  on public.storage_cleanup_operational_alerts (claimed_at, id)
  where status = 'processing';

alter table public.storage_cleanup_operational_alerts
  enable row level security;

create trigger storage_cleanup_operational_alerts_set_updated_at
  before update on public.storage_cleanup_operational_alerts
  for each row
  execute function public.set_updated_at();

revoke all on table public.storage_cleanup_operational_alerts
  from public, anon, authenticated;
grant all on table public.storage_cleanup_operational_alerts
  to service_role;

create or replace function private.storage_cleanup_cron_health()
returns table (
  cron_status text,
  last_succeeded_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if to_regclass('cron.job') is null
    or to_regclass('cron.job_run_details') is null
  then
    return query select 'missing'::text, null::timestamptz;
    return;
  end if;

  return query execute $query$
    with matching_jobs as (
      select
        job.jobid,
        job.schedule,
        job.active
      from cron.job as job
      where job.jobname = 'process-storage-cleanup-backlog'
    ),
    job_summary as (
      select
        count(*)::integer as job_count,
        count(*) filter (where active)::integer as active_job_count,
        count(*) filter (
          where active and schedule = '*/5 * * * *'
        )::integer as correctly_scheduled_job_count
      from matching_jobs
    ),
    run_summary as (
      select
        max(coalesce(run.end_time, run.start_time))
          filter (where lower(run.status) = 'succeeded')
          as last_succeeded_at
      from cron.job_run_details as run
      join matching_jobs as job
        on job.jobid = run.jobid
    )
    select
      case
        when job_summary.job_count = 0 then 'missing'
        when job_summary.job_count > 1 then 'duplicate'
        when job_summary.active_job_count = 0 then 'inactive'
        when job_summary.correctly_scheduled_job_count = 0
          then 'schedule_mismatch'
        when run_summary.last_succeeded_at is null
          then 'never_succeeded'
        when run_summary.last_succeeded_at < now() - interval '15 minutes'
          then 'stale'
        else 'healthy'
      end,
      run_summary.last_succeeded_at
    from job_summary
    cross join run_summary
  $query$;
end;
$$;

revoke all on function private.storage_cleanup_cron_health()
  from public, anon, authenticated;

create or replace function private.sync_storage_cleanup_health(
  requested_issue_codes text[],
  requested_failed_request_count integer,
  requested_stale_processing_count integer,
  requested_overdue_pending_count integer,
  requested_cleanup_cron_status text,
  requested_cleanup_cron_last_succeeded_at timestamptz,
  requested_evaluated_at timestamptz default now()
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  allowed_issue_codes constant text[] := array[
    'failed_requests',
    'stale_processing',
    'overdue_pending',
    'cleanup_cron_missing',
    'cleanup_cron_duplicate',
    'cleanup_cron_inactive',
    'cleanup_cron_schedule_mismatch',
    'cleanup_cron_never_succeeded',
    'cleanup_cron_stale'
  ]::text[];
  normalized_issue_codes text[] := coalesce(
    requested_issue_codes,
    '{}'::text[]
  );
  normalized_issue_signature text :=
    array_to_string(normalized_issue_codes, ',');
  next_status text;
  next_incident_id uuid;
  next_incident_started_at timestamptz;
  alert_kind text;
  alert_incident_id uuid;
  alert_incident_started_at timestamptz;
  alert_issue_signature text;
  alert_issue_codes text[];
  previous_state public.storage_cleanup_health_state%rowtype;
  queued_alert_count integer := 0;
begin
  if requested_evaluated_at is null then
    perform private.raise_app_error('invalid_storage_cleanup_evaluated_at');
  end if;

  if requested_failed_request_count is null
    or requested_failed_request_count < 0
    or requested_stale_processing_count is null
    or requested_stale_processing_count < 0
    or requested_overdue_pending_count is null
    or requested_overdue_pending_count < 0
  then
    perform private.raise_app_error('invalid_storage_cleanup_health_counts');
  end if;

  if requested_cleanup_cron_status is null
    or requested_cleanup_cron_status not in (
      'healthy',
      'missing',
      'duplicate',
      'inactive',
      'schedule_mismatch',
      'never_succeeded',
      'stale'
    )
  then
    perform private.raise_app_error('invalid_storage_cleanup_cron_status');
  end if;

  if exists (
    select 1
    from unnest(normalized_issue_codes) as issue(code)
    where issue.code <> all (allowed_issue_codes)
  ) or cardinality(normalized_issue_codes) <>
    (
      select count(distinct issue.code)
      from unnest(normalized_issue_codes) as issue(code)
    )
  then
    perform private.raise_app_error('invalid_storage_cleanup_issue_codes');
  end if;

  next_status := case
    when cardinality(normalized_issue_codes) = 0 then 'healthy'
    else 'degraded'
  end;

  perform pg_advisory_xact_lock(
    hashtextextended('storage_cleanup_health_state', 0)
  );

  select state.*
  into previous_state
  from public.storage_cleanup_health_state as state
  where state.monitor_key = 'storage_cleanup'
  for update;

  if not found then
    if next_status = 'degraded' then
      next_incident_id := gen_random_uuid();
      next_incident_started_at := requested_evaluated_at;
      alert_kind := 'degraded';
      alert_incident_id := next_incident_id;
      alert_incident_started_at := next_incident_started_at;
      alert_issue_signature := normalized_issue_signature;
      alert_issue_codes := normalized_issue_codes;
    end if;

    insert into public.storage_cleanup_health_state (
      monitor_key,
      status,
      issue_signature,
      issue_codes,
      incident_id,
      incident_started_at,
      failed_request_count,
      stale_processing_count,
      overdue_pending_count,
      cleanup_cron_status,
      cleanup_cron_last_succeeded_at,
      last_evaluated_at,
      last_changed_at
    )
    values (
      'storage_cleanup',
      next_status,
      normalized_issue_signature,
      normalized_issue_codes,
      next_incident_id,
      next_incident_started_at,
      requested_failed_request_count,
      requested_stale_processing_count,
      requested_overdue_pending_count,
      requested_cleanup_cron_status,
      requested_cleanup_cron_last_succeeded_at,
      requested_evaluated_at,
      requested_evaluated_at
    );
  else
    if previous_state.status = 'healthy' and next_status = 'degraded' then
      next_incident_id := gen_random_uuid();
      next_incident_started_at := requested_evaluated_at;
      alert_kind := 'degraded';
      alert_incident_id := next_incident_id;
      alert_incident_started_at := next_incident_started_at;
      alert_issue_signature := normalized_issue_signature;
      alert_issue_codes := normalized_issue_codes;
    elsif previous_state.status = 'degraded'
      and next_status = 'degraded'
    then
      next_incident_id := previous_state.incident_id;
      next_incident_started_at := previous_state.incident_started_at;

      if previous_state.issue_signature <> normalized_issue_signature then
        alert_kind := 'degraded';
        alert_incident_id := next_incident_id;
        alert_incident_started_at := next_incident_started_at;
        alert_issue_signature := normalized_issue_signature;
        alert_issue_codes := normalized_issue_codes;
      end if;
    elsif previous_state.status = 'degraded'
      and next_status = 'healthy'
    then
      alert_kind := 'recovered';
      alert_incident_id := previous_state.incident_id;
      alert_incident_started_at := previous_state.incident_started_at;
      alert_issue_signature := previous_state.issue_signature;
      alert_issue_codes := previous_state.issue_codes;
    end if;

    update public.storage_cleanup_health_state
    set
      status = next_status,
      issue_signature = normalized_issue_signature,
      issue_codes = normalized_issue_codes,
      incident_id = next_incident_id,
      incident_started_at = next_incident_started_at,
      failed_request_count = requested_failed_request_count,
      stale_processing_count = requested_stale_processing_count,
      overdue_pending_count = requested_overdue_pending_count,
      cleanup_cron_status = requested_cleanup_cron_status,
      cleanup_cron_last_succeeded_at =
        requested_cleanup_cron_last_succeeded_at,
      last_evaluated_at = requested_evaluated_at,
      last_changed_at = case
        when previous_state.status <> next_status
          or previous_state.issue_signature <> normalized_issue_signature
        then requested_evaluated_at
        else previous_state.last_changed_at
      end
    where monitor_key = 'storage_cleanup';
  end if;

  if alert_kind is not null then
    insert into public.storage_cleanup_operational_alerts (
      incident_id,
      alert_kind,
      issue_signature,
      issue_codes,
      failed_request_count,
      stale_processing_count,
      overdue_pending_count,
      cleanup_cron_status,
      cleanup_cron_last_succeeded_at,
      detected_at,
      incident_started_at
    )
    values (
      alert_incident_id,
      alert_kind,
      alert_issue_signature,
      alert_issue_codes,
      requested_failed_request_count,
      requested_stale_processing_count,
      requested_overdue_pending_count,
      requested_cleanup_cron_status,
      requested_cleanup_cron_last_succeeded_at,
      requested_evaluated_at,
      alert_incident_started_at
    )
    on conflict do nothing;

    get diagnostics queued_alert_count = row_count;
  end if;

  return queued_alert_count;
end;
$$;

revoke all on function private.sync_storage_cleanup_health(
  text[],
  integer,
  integer,
  integer,
  text,
  timestamptz,
  timestamptz
) from public, anon, authenticated;

create or replace function public.evaluate_storage_cleanup_health()
returns table (
  health_status text,
  issue_codes text[],
  failed_request_count integer,
  stale_processing_count integer,
  overdue_pending_count integer,
  cleanup_cron_status text,
  cleanup_cron_last_succeeded_at timestamptz,
  evaluated_at timestamptz,
  queued_alert_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_evaluated_at timestamptz := now();
  current_failed_request_count integer;
  current_stale_processing_count integer;
  current_overdue_pending_count integer;
  current_cleanup_cron_status text;
  current_cleanup_cron_last_succeeded_at timestamptz;
  current_issue_codes text[] := '{}'::text[];
  current_queued_alert_count integer;
begin
  select
    count(*) filter (where request.status = 'failed')::integer,
    count(*) filter (
      where request.status = 'processing'
        and (
          request.claimed_at is null
          or request.claimed_at <=
            current_evaluated_at - interval '10 minutes'
        )
    )::integer,
    count(*) filter (
      where request.status = 'pending'
        and request.available_at <= current_evaluated_at
        and request.created_at <=
          current_evaluated_at - interval '60 minutes'
    )::integer
  into
    current_failed_request_count,
    current_stale_processing_count,
    current_overdue_pending_count
  from public.storage_cleanup_requests as request;

  select cron.cron_status, cron.last_succeeded_at
  into
    current_cleanup_cron_status,
    current_cleanup_cron_last_succeeded_at
  from private.storage_cleanup_cron_health() as cron;

  if current_failed_request_count > 0 then
    current_issue_codes := array_append(
      current_issue_codes,
      'failed_requests'
    );
  end if;
  if current_stale_processing_count > 0 then
    current_issue_codes := array_append(
      current_issue_codes,
      'stale_processing'
    );
  end if;
  if current_overdue_pending_count > 0 then
    current_issue_codes := array_append(
      current_issue_codes,
      'overdue_pending'
    );
  end if;
  if current_cleanup_cron_status <> 'healthy' then
    current_issue_codes := array_append(
      current_issue_codes,
      'cleanup_cron_' || current_cleanup_cron_status
    );
  end if;

  current_queued_alert_count := private.sync_storage_cleanup_health(
    current_issue_codes,
    current_failed_request_count,
    current_stale_processing_count,
    current_overdue_pending_count,
    current_cleanup_cron_status,
    current_cleanup_cron_last_succeeded_at,
    current_evaluated_at
  );

  return query select
    case
      when cardinality(current_issue_codes) = 0 then 'healthy'
      else 'degraded'
    end,
    current_issue_codes,
    current_failed_request_count,
    current_stale_processing_count,
    current_overdue_pending_count,
    current_cleanup_cron_status,
    current_cleanup_cron_last_succeeded_at,
    current_evaluated_at,
    current_queued_alert_count;
end;
$$;

create or replace function public.claim_storage_cleanup_operational_alerts(
  requested_worker_id text,
  requested_limit integer default 20
)
returns table (
  alert_id uuid,
  incident_id uuid,
  claim_token uuid,
  attempt_count integer,
  max_attempts integer,
  alert_kind text,
  issue_codes text[],
  failed_request_count integer,
  stale_processing_count integer,
  overdue_pending_count integer,
  cleanup_cron_status text,
  cleanup_cron_last_succeeded_at timestamptz,
  detected_at timestamptz,
  incident_started_at timestamptz
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
    perform private.raise_app_error(
      'invalid_storage_cleanup_alert_worker_id'
    );
  end if;

  if requested_limit is null
    or requested_limit < 1
    or requested_limit > 100
  then
    perform private.raise_app_error(
      'invalid_storage_cleanup_alert_claim_limit'
    );
  end if;

  update public.storage_cleanup_operational_alerts as alert
  set
    status = 'failed',
    claim_token = null,
    claimed_by = null,
    claimed_at = null,
    completed_at = now(),
    last_error = coalesce(
      alert.last_error,
      'storage_cleanup_alert_abandoned_after_final_attempt'
    )
  where alert.status = 'processing'
    and (
      alert.claimed_at is null
      or alert.claimed_at < stale_claimed_before
    )
    and alert.attempt_count >= alert.max_attempts;

  return query
  with candidates as (
    select alert.id
    from public.storage_cleanup_operational_alerts as alert
    where alert.attempt_count < alert.max_attempts
      and (
        (
          alert.status = 'pending'
          and alert.available_at <= now()
        )
        or (
          alert.status = 'processing'
          and (
            alert.claimed_at is null
            or alert.claimed_at < stale_claimed_before
          )
        )
      )
    order by alert.available_at, alert.created_at, alert.id
    for update skip locked
    limit requested_limit
  ),
  claimed as (
    update public.storage_cleanup_operational_alerts as alert
    set
      status = 'processing',
      attempt_count = alert.attempt_count + 1,
      claim_token = gen_random_uuid(),
      claimed_by = normalized_worker_id,
      claimed_at = now(),
      completed_at = null,
      last_error = null
    from candidates
    where alert.id = candidates.id
    returning alert.*
  )
  select
    claimed.id,
    claimed.incident_id,
    claimed.claim_token,
    claimed.attempt_count,
    claimed.max_attempts,
    claimed.alert_kind,
    claimed.issue_codes,
    claimed.failed_request_count,
    claimed.stale_processing_count,
    claimed.overdue_pending_count,
    claimed.cleanup_cron_status,
    claimed.cleanup_cron_last_succeeded_at,
    claimed.detected_at,
    claimed.incident_started_at
  from claimed
  order by claimed.created_at, claimed.id;
end;
$$;

create or replace function public.complete_storage_cleanup_operational_alert(
  requested_alert_id uuid,
  requested_claim_token uuid,
  requested_delivered boolean,
  requested_retryable boolean,
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
  claimed_alert public.storage_cleanup_operational_alerts%rowtype;
  next_status text;
begin
  if requested_alert_id is null or requested_claim_token is null then
    perform private.raise_app_error(
      'invalid_storage_cleanup_alert_claim'
    );
  end if;

  if requested_delivered is null or requested_retryable is null then
    perform private.raise_app_error(
      'invalid_storage_cleanup_alert_result'
    );
  end if;

  if requested_retry_delay_seconds is null
    or requested_retry_delay_seconds < 0
    or requested_retry_delay_seconds > 3600
  then
    perform private.raise_app_error(
      'invalid_storage_cleanup_alert_retry_delay'
    );
  end if;

  if normalized_error is not null
    and char_length(normalized_error) > 2000
  then
    perform private.raise_app_error(
      'storage_cleanup_alert_error_too_long'
    );
  end if;

  if not requested_delivered and normalized_error is null then
    perform private.raise_app_error(
      'storage_cleanup_alert_error_required'
    );
  end if;

  select alert.*
  into claimed_alert
  from public.storage_cleanup_operational_alerts as alert
  where alert.id = requested_alert_id
    and alert.status = 'processing'
    and alert.claim_token = requested_claim_token
  for update;

  if not found then
    return 'stale';
  end if;

  if requested_delivered then
    next_status := 'delivered';

    update public.storage_cleanup_operational_alerts
    set
      status = next_status,
      claim_token = null,
      claimed_by = null,
      claimed_at = null,
      delivered_at = now(),
      completed_at = now(),
      last_error = null
    where id = claimed_alert.id;
  elsif not requested_retryable
    or claimed_alert.attempt_count >= claimed_alert.max_attempts
  then
    next_status := 'failed';

    update public.storage_cleanup_operational_alerts
    set
      status = next_status,
      claim_token = null,
      claimed_by = null,
      claimed_at = null,
      completed_at = now(),
      last_error = normalized_error
    where id = claimed_alert.id;
  else
    next_status := 'pending';

    update public.storage_cleanup_operational_alerts
    set
      status = next_status,
      available_at =
        now() + make_interval(secs => requested_retry_delay_seconds),
      claim_token = null,
      claimed_by = null,
      claimed_at = null,
      completed_at = null,
      last_error = normalized_error
    where id = claimed_alert.id;
  end if;

  return next_status;
end;
$$;

revoke execute on function public.evaluate_storage_cleanup_health()
  from public, anon, authenticated;
revoke execute on function public.claim_storage_cleanup_operational_alerts(
  text,
  integer
) from public, anon, authenticated;
revoke execute on function public.complete_storage_cleanup_operational_alert(
  uuid,
  uuid,
  boolean,
  boolean,
  text,
  integer
) from public, anon, authenticated;

grant execute on function public.evaluate_storage_cleanup_health()
  to service_role;
grant execute on function public.claim_storage_cleanup_operational_alerts(
  text,
  integer
) to service_role;
grant execute on function public.complete_storage_cleanup_operational_alert(
  uuid,
  uuid,
  boolean,
  boolean,
  text,
  integer
) to service_role;
