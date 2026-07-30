begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(34);

select has_table(
  'public',
  'storage_cleanup_health_state',
  'storage cleanup monitoring has a durable health state'
);
select has_table(
  'public',
  'storage_cleanup_operational_alerts',
  'storage cleanup monitoring has a durable alert outbox'
);
select has_function(
  'public',
  'evaluate_storage_cleanup_health',
  array[]::text[],
  'the monitor evaluates cleanup health through one boundary'
);
select has_function(
  'public',
  'claim_storage_cleanup_operational_alerts',
  array['text', 'integer'],
  'the monitor claims operational alerts through one boundary'
);
select has_function(
  'public',
  'complete_storage_cleanup_operational_alert',
  array['uuid', 'uuid', 'boolean', 'boolean', 'text', 'integer'],
  'the monitor completes operational alerts through one boundary'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.storage_cleanup_health_state',
    'SELECT'
  ),
  'clients cannot inspect storage cleanup health'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.storage_cleanup_operational_alerts',
    'SELECT'
  ),
  'clients cannot inspect operational alerts'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.evaluate_storage_cleanup_health()',
    'EXECUTE'
  ),
  'clients cannot run the cleanup monitor'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.evaluate_storage_cleanup_health()',
    'EXECUTE'
  ),
  'the service worker can run the cleanup monitor'
);

select is(
  private.sync_storage_cleanup_health(
    '{}'::text[],
    0,
    0,
    0,
    'healthy',
    '2026-07-30 00:00:00+00',
    '2026-07-30 00:01:00+00'
  ),
  0,
  'the initial healthy state does not queue an alert'
);
select is(
  (
    select status
    from public.storage_cleanup_health_state
    where monitor_key = 'storage_cleanup'
  ),
  'healthy',
  'the initial evaluation records a healthy state'
);

select is(
  private.sync_storage_cleanup_health(
    array['failed_requests'],
    2,
    0,
    0,
    'healthy',
    '2026-07-30 00:00:00+00',
    '2026-07-30 00:02:00+00'
  ),
  1,
  'a new degraded state queues one operational alert'
);
select is(
  (
    select count(*)
    from public.storage_cleanup_operational_alerts
    where alert_kind = 'degraded'
  ),
  1::bigint,
  'one degraded transition produces one alert'
);
select is(
  private.sync_storage_cleanup_health(
    array['failed_requests'],
    3,
    0,
    0,
    'healthy',
    '2026-07-30 00:00:00+00',
    '2026-07-30 00:03:00+00'
  ),
  0,
  'count changes do not duplicate the same incident condition'
);
select is(
  (
    select count(*)
    from public.storage_cleanup_operational_alerts
    where alert_kind = 'degraded'
  ),
  1::bigint,
  'the same incident condition remains deduplicated'
);

select is(
  private.sync_storage_cleanup_health(
    array['failed_requests', 'cleanup_cron_stale'],
    3,
    0,
    0,
    'stale',
    '2026-07-29 23:00:00+00',
    '2026-07-30 00:04:00+00'
  ),
  1,
  'a changed incident condition queues one updated alert'
);
select is(
  (
    select count(distinct incident_id)
    from public.storage_cleanup_operational_alerts
    where alert_kind = 'degraded'
  ),
  1::bigint,
  'changed conditions stay within the same incident'
);
select is(
  (
    select count(*)
    from public.storage_cleanup_operational_alerts
    where alert_kind = 'degraded'
  ),
  2::bigint,
  'the changed condition has its own deduplicated alert'
);

select is(
  private.sync_storage_cleanup_health(
    '{}'::text[],
    0,
    0,
    0,
    'healthy',
    '2026-07-30 00:05:00+00',
    '2026-07-30 00:05:00+00'
  ),
  1,
  'recovery queues one operational alert'
);
select is(
  (
    select count(*)
    from public.storage_cleanup_operational_alerts
    where alert_kind = 'recovered'
  ),
  1::bigint,
  'the incident produces one recovery alert'
);
select is(
  (
    select status
    from public.storage_cleanup_health_state
    where monitor_key = 'storage_cleanup'
  ),
  'healthy',
  'recovery clears the degraded state'
);

create temporary table storage_cleanup_alert_test_claims (
  claim_number integer primary key,
  alert_id uuid not null,
  claim_token uuid not null
);
grant select, insert on table storage_cleanup_alert_test_claims
  to service_role;

set local role service_role;

insert into storage_cleanup_alert_test_claims (
  claim_number,
  alert_id,
  claim_token
)
select
  row_number() over (
    order by claimed.detected_at, claimed.alert_id
  )::integer,
  claimed.alert_id,
  claimed.claim_token
from public.claim_storage_cleanup_operational_alerts(
  'storage-alert-test-worker',
  10
) as claimed;

reset role;

select is(
  (select count(*) from storage_cleanup_alert_test_claims),
  3::bigint,
  'the worker claims all queued incident transitions'
);
select is(
  (
    select count(*)
    from public.storage_cleanup_operational_alerts
    where status = 'processing'
  ),
  3::bigint,
  'claimed alerts move into processing'
);
select is(
  (
    select min(attempt_count)
    from public.storage_cleanup_operational_alerts
  ),
  1,
  'claiming records the first delivery attempt'
);

set local role service_role;

select is(
  public.complete_storage_cleanup_operational_alert(
    (
      select alert_id
      from storage_cleanup_alert_test_claims
      where claim_number = 1
    ),
    (
      select claim_token
      from storage_cleanup_alert_test_claims
      where claim_number = 1
    ),
    false,
    true,
    'discord_webhook_unavailable',
    0
  ),
  'pending',
  'a retryable delivery failure returns the alert to pending'
);
select is(
  public.complete_storage_cleanup_operational_alert(
    (
      select alert_id
      from storage_cleanup_alert_test_claims
      where claim_number = 2
    ),
    (
      select claim_token
      from storage_cleanup_alert_test_claims
      where claim_number = 2
    ),
    false,
    false,
    'discord_webhook_rejected',
    0
  ),
  'failed',
  'a terminal receiver rejection stops retrying'
);
select is(
  public.complete_storage_cleanup_operational_alert(
    (
      select alert_id
      from storage_cleanup_alert_test_claims
      where claim_number = 3
    ),
    (
      select claim_token
      from storage_cleanup_alert_test_claims
      where claim_number = 3
    ),
    true,
    false,
    null,
    0
  ),
  'delivered',
  'a successful delivery completes the alert'
);

reset role;

select is(
  (
    select count(*)
    from public.storage_cleanup_operational_alerts
    where status = 'pending'
  ),
  1::bigint,
  'one retryable alert remains pending'
);
select is(
  (
    select count(*)
    from public.storage_cleanup_operational_alerts
    where status = 'failed'
  ),
  1::bigint,
  'one rejected alert remains failed for inspection'
);
select is(
  (
    select count(*)
    from public.storage_cleanup_operational_alerts
    where status = 'delivered'
  ),
  1::bigint,
  'one delivered alert remains as an audit record'
);
select ok(
  (
    select delivered_at is not null
    from public.storage_cleanup_operational_alerts
    where status = 'delivered'
  ),
  'successful delivery records its completion time'
);
select ok(
  (
    select completed_at is not null
    from public.storage_cleanup_operational_alerts
    where status = 'failed'
  ),
  'terminal delivery failure records its completion time'
);
select is(
  (
    select count(*)
    from public.storage_cleanup_operational_alerts
    where issue_codes && array[
      'failed_requests',
      'cleanup_cron_stale'
    ]::text[]
  ),
  3::bigint,
  'alerts retain only bounded operational issue codes'
);

select throws_ok(
  $$
    select private.sync_storage_cleanup_health(
      array['private/object/path'],
      0,
      0,
      0,
      'healthy',
      null,
      now()
    )
  $$,
  'P0001',
  'invalid_storage_cleanup_issue_codes',
  'arbitrary values cannot enter operational alert payloads'
);

select * from finish();
rollback;
