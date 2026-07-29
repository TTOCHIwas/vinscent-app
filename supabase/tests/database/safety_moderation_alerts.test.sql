begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(24);

create temporary table safety_moderation_test_claims (
  claim_number integer primary key,
  report_id uuid not null,
  claim_token uuid not null
);
grant select, insert on table safety_moderation_test_claims to service_role;

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '1b000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'moderation-reporter@example.test',
    now(),
    now()
  ),
  (
    '1b000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'moderation-reported@example.test',
    now(),
    now()
  );

insert into public.safety_reports (
  id,
  reporter_user_id,
  reported_user_id,
  couple_id,
  target_type,
  target_id,
  reason,
  details,
  content_snapshot
)
values (
  '2b000000-0000-0000-0000-000000000001',
  '1b000000-0000-0000-0000-000000000001',
  '1b000000-0000-0000-0000-000000000002',
  '3b000000-0000-0000-0000-000000000001',
  'story_card',
  '4b000000-0000-0000-0000-000000000001',
  'harassment',
  '검토가 필요한 신고',
  '신고 시점의 콘텐츠'
);

select has_table(
  'public',
  'safety_moderation_alerts',
  'safety reports have a durable moderation alert outbox'
);
select has_function(
  'public',
  'claim_safety_moderation_alerts',
  array['text', 'integer'],
  'moderation workers claim alerts through one boundary'
);
select has_function(
  'public',
  'complete_safety_moderation_alert',
  array['uuid', 'uuid', 'boolean', 'text', 'integer'],
  'moderation workers complete alerts through one boundary'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.safety_moderation_alerts',
    'SELECT'
  ),
  'clients cannot inspect the moderation alert queue'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.claim_safety_moderation_alerts(text,integer)',
    'EXECUTE'
  ),
  'clients cannot claim moderation alerts'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.claim_safety_moderation_alerts(text,integer)',
    'EXECUTE'
  ),
  'the service worker can claim moderation alerts'
);
select is(
  (
    select status
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  'pending',
  'a new report queues one pending moderation alert'
);
select is(
  (
    select attempt_count
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  0,
  'a new alert starts without a delivery attempt'
);

set local role service_role;

insert into safety_moderation_test_claims (
  claim_number,
  report_id,
  claim_token
)
select
  1,
  claimed.report_id,
  claimed.claim_token
from public.claim_safety_moderation_alerts('moderation-test-worker', 10)
  as claimed;

reset role;

select is(
  (select count(*) from safety_moderation_test_claims),
  1::bigint,
  'one worker claims the queued alert'
);
select is(
  (
    select status
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  'processing',
  'claiming moves the alert into processing'
);
select is(
  (
    select attempt_count
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  1,
  'claiming records the first attempt'
);

update public.safety_reports
set reason = reason
where id = '2b000000-0000-0000-0000-000000000001';

select is(
  (
    select status
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  'processing',
  'an unchanged duplicate does not reset an active alert'
);

set local role service_role;

select is(
  public.complete_safety_moderation_alert(
    '2b000000-0000-0000-0000-000000000001',
    (
      select claim_token
      from safety_moderation_test_claims
      where claim_number = 1
    ),
    false,
    'temporary transport failure',
    0
  ),
  'pending',
  'a retryable delivery failure returns the alert to pending'
);

insert into safety_moderation_test_claims (
  claim_number,
  report_id,
  claim_token
)
select
  2,
  claimed.report_id,
  claimed.claim_token
from public.claim_safety_moderation_alerts('moderation-test-worker', 10)
  as claimed;

reset role;

select is(
  (
    select status
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  'processing',
  'a due retry can be claimed again'
);
select is(
  (
    select attempt_count
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  2,
  'a retry increments the delivery attempt'
);
select isnt(
  (
    select claim_token
    from safety_moderation_test_claims
    where claim_number = 1
  ),
  (
    select claim_token
    from safety_moderation_test_claims
    where claim_number = 2
  ),
  'each claim receives a new ownership token'
);

set local role service_role;

select is(
  public.complete_safety_moderation_alert(
    '2b000000-0000-0000-0000-000000000001',
    (
      select claim_token
      from safety_moderation_test_claims
      where claim_number = 2
    ),
    true,
    null,
    60
  ),
  'delivered',
  'a successful transport marks the alert delivered'
);

reset role;

select ok(
  (
    select delivered_at is not null
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  'successful delivery records its completion time'
);

update public.safety_reports
set
  status = 'reviewed',
  reviewed_at = now(),
  moderation_note = '확인함'
where id = '2b000000-0000-0000-0000-000000000001';

select is(
  (
    select status
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  'delivered',
  'reviewing a report preserves a delivered alert audit record'
);

update public.safety_reports
set reason = 'privacy'
where id = '2b000000-0000-0000-0000-000000000001';

select is(
  (
    select status
    from public.safety_reports
    where id = '2b000000-0000-0000-0000-000000000001'
  ),
  'pending',
  'changed resolved content returns the report to review'
);
select is(
  (
    select status
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  'pending',
  'changed resolved content queues a fresh alert'
);
select is(
  (
    select attempt_count
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  0,
  'a fresh alert resets earlier transport attempts'
);

update public.safety_reports
set
  status = 'dismissed',
  reviewed_at = now(),
  moderation_note = '기각'
where id = '2b000000-0000-0000-0000-000000000001';

select is(
  (
    select status
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  'cancelled',
  'resolving a report cancels an alert that was not delivered'
);
select ok(
  (
    select completed_at is not null
    from public.safety_moderation_alerts
    where report_id = '2b000000-0000-0000-0000-000000000001'
  ),
  'a cancelled alert records its completion time'
);

select * from finish();
rollback;
