begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(34);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values (
  '15000000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'push-receiver@example.test',
  now(),
  now()
);

select has_column(
  'public',
  'push_notification_dispatches',
  'claim_token',
  'dispatch claims have an ownership token'
);

create temporary table first_claim as
select *
from public.claim_push_notification_dispatch(
  'recording_activity',
  '25000000-0000-0000-0000-000000000001',
  '15000000-0000-0000-0000-000000000001'
);

select isnt(
  (select claim_token from first_claim),
  null::uuid,
  'claim returns a non-null ownership token'
);

select is(
  (select max_attempts from first_claim),
  1,
  'legacy three-argument claims remain single-attempt during deployment'
);

select is(
  (
    select claim_token
    from public.push_notification_dispatches
    where notification_type = 'recording_activity'
      and source_id = '25000000-0000-0000-0000-000000000001'
      and receiver_user_id = '15000000-0000-0000-0000-000000000001'
  ),
  (select claim_token from first_claim),
  'stored dispatch ownership matches the claim response'
);

select lives_ok(
  format(
    $sql$
      select public.complete_push_notification_delivery(
        'recording_activity',
        '25000000-0000-0000-0000-000000000001',
        '15000000-0000-0000-0000-000000000001',
        %L,
        2,
        2,
        0,
        'sent',
        null
      )
    $sql$,
    (select claim_token from first_claim)
  ),
  'claim owner can atomically complete a delivery'
);

select is(
  (
    select status
    from public.push_notification_dispatches
    where notification_type = 'recording_activity'
      and source_id = '25000000-0000-0000-0000-000000000001'
      and receiver_user_id = '15000000-0000-0000-0000-000000000001'
  ),
  'sent',
  'atomic completion finalizes the dispatch'
);

select is(
  (
    select count(*)
    from public.push_notification_deliveries
    where notification_type = 'recording_activity'
      and source_id = '25000000-0000-0000-0000-000000000001'
      and receiver_user_id = '15000000-0000-0000-0000-000000000001'
  ),
  1::bigint,
  'atomic completion writes one delivery record'
);

select results_eq(
  $$
    select target_token_count, success_count, failure_count
    from public.push_notification_deliveries
    where notification_type = 'recording_activity'
      and source_id = '25000000-0000-0000-0000-000000000001'
      and receiver_user_id = '15000000-0000-0000-0000-000000000001'
  $$,
  $$ values (2, 2, 0) $$,
  'delivery counts are persisted without loss'
);

select lives_ok(
  format(
    $sql$
      select public.complete_push_notification_delivery(
        'recording_activity',
        '25000000-0000-0000-0000-000000000001',
        '15000000-0000-0000-0000-000000000001',
        %L,
        2,
        2,
        0,
        'sent',
        null
      )
    $sql$,
    (select claim_token from first_claim)
  ),
  'repeating the same completion is idempotent'
);

select is(
  (
    select count(*)
    from public.push_notification_deliveries
    where notification_type = 'recording_activity'
      and source_id = '25000000-0000-0000-0000-000000000001'
      and receiver_user_id = '15000000-0000-0000-0000-000000000001'
  ),
  1::bigint,
  'idempotent completion does not duplicate delivery records'
);

create temporary table second_claim as
select *
from public.claim_push_notification_dispatch(
  'recording_activity',
  '25000000-0000-0000-0000-000000000002',
  '15000000-0000-0000-0000-000000000001'
);

select throws_ok(
  $$
    select public.complete_push_notification_delivery(
      'recording_activity',
      '25000000-0000-0000-0000-000000000002',
      '15000000-0000-0000-0000-000000000001',
      '35000000-0000-0000-0000-000000000001',
      1,
      1,
      0,
      'sent',
      null
    )
  $$,
  'P0001',
  'dispatch_claim_lost',
  'a different claim owner cannot complete the dispatch'
);

select is(
  (
    select status
    from public.push_notification_dispatches
    where notification_type = 'recording_activity'
      and source_id = '25000000-0000-0000-0000-000000000002'
      and receiver_user_id = '15000000-0000-0000-0000-000000000001'
  ),
  'processing',
  'rejected completion leaves the active dispatch unchanged'
);

select is(
  (
    select count(*)
    from public.push_notification_deliveries
    where notification_type = 'recording_activity'
      and source_id = '25000000-0000-0000-0000-000000000002'
      and receiver_user_id = '15000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'rejected completion does not create a delivery record'
);

select has_column(
  'public',
  'push_notification_dispatches',
  'title',
  'retryable dispatches retain their notification title'
);

select has_column(
  'public',
  'push_notification_dispatches',
  'body',
  'retryable dispatches retain their notification body'
);

select has_column(
  'public',
  'push_notification_dispatches',
  'data',
  'retryable dispatches retain their route payload'
);

select has_column(
  'public',
  'push_notification_dispatches',
  'attempt_count',
  'dispatches count delivery attempts'
);

select has_column(
  'public',
  'push_notification_dispatches',
  'max_attempts',
  'dispatches bound delivery attempts'
);

select has_column(
  'public',
  'push_notification_dispatches',
  'available_at',
  'failed dispatches expose their next retry time'
);

create temporary table retry_first_claim as
select *
from public.claim_push_notification_dispatch(
  requested_notification_type => 'calendar_event_reminder',
  requested_source_id => '25000000-0000-0000-0000-000000000003',
  requested_receiver_user_id => '15000000-0000-0000-0000-000000000001',
  requested_title => 'Vinscent',
  requested_body => '오늘은 함께 걷는 일정이 있어요.',
  requested_data => jsonb_build_object(
    'event_id',
    '35000000-0000-0000-0000-000000000001'
  ),
  requested_preference_column => null,
  requested_max_attempts => 5
);

select is(
  (select attempt_count from retry_first_claim),
  1,
  'the first delivery claim records one attempt'
);

select is(
  (
    select title
    from public.push_notification_dispatches
    where notification_type = 'calendar_event_reminder'
      and source_id = '25000000-0000-0000-0000-000000000003'
      and receiver_user_id = '15000000-0000-0000-0000-000000000001'
  ),
  'Vinscent',
  'the first claim persists retry payload metadata'
);

select lives_ok(
  format(
    $sql$
      select public.complete_push_notification_delivery(
        'calendar_event_reminder',
        '25000000-0000-0000-0000-000000000003',
        '15000000-0000-0000-0000-000000000001',
        %L,
        1,
        0,
        1,
        'failed',
        'status=UNAVAILABLE'
      )
    $sql$,
    (select claim_token from retry_first_claim)
  ),
  'a failed delivery is persisted for retry'
);

select is(
  (
    select status
    from public.push_notification_dispatches
    where notification_type = 'calendar_event_reminder'
      and source_id = '25000000-0000-0000-0000-000000000003'
      and receiver_user_id = '15000000-0000-0000-0000-000000000001'
  ),
  'failed',
  'a retryable delivery remains failed until the next claim'
);

select ok(
  (
    select available_at > now()
    from public.push_notification_dispatches
    where notification_type = 'calendar_event_reminder'
      and source_id = '25000000-0000-0000-0000-000000000003'
      and receiver_user_id = '15000000-0000-0000-0000-000000000001'
  ),
  'a failed delivery receives exponential retry delay'
);

update public.push_notification_dispatches
set available_at = now() - interval '1 second'
where notification_type = 'calendar_event_reminder'
  and source_id = '25000000-0000-0000-0000-000000000003'
  and receiver_user_id = '15000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)
    from public.get_retryable_push_notification_dispatches(10)
    where notification_type = 'calendar_event_reminder'
      and source_id = '25000000-0000-0000-0000-000000000003'
  ),
  1::bigint,
  'the retry loader exposes an eligible failed dispatch'
);

create temporary table retry_second_claim as
select *
from public.claim_push_notification_dispatch(
  requested_notification_type => 'calendar_event_reminder',
  requested_source_id => '25000000-0000-0000-0000-000000000003',
  requested_receiver_user_id => '15000000-0000-0000-0000-000000000001',
  requested_title => 'Vinscent',
  requested_body => '오늘은 함께 걷는 일정이 있어요.',
  requested_data => jsonb_build_object(
    'event_id',
    '35000000-0000-0000-0000-000000000001'
  ),
  requested_preference_column => null,
  requested_max_attempts => 5
);

select is(
  (select claim_result from retry_second_claim),
  'claimed',
  'an eligible failed dispatch can be claimed again'
);

select is(
  (select attempt_count from retry_second_claim),
  2,
  'a retry increments the delivery attempt'
);

select lives_ok(
  format(
    $sql$
      select public.complete_push_notification_delivery(
        'calendar_event_reminder',
        '25000000-0000-0000-0000-000000000003',
        '15000000-0000-0000-0000-000000000001',
        %L,
        1,
        1,
        0,
        'sent',
        null
      )
    $sql$,
    (select claim_token from retry_second_claim)
  ),
  'a later retry can complete successfully'
);

select is(
  (
    select status
    from public.push_notification_dispatches
    where notification_type = 'calendar_event_reminder'
      and source_id = '25000000-0000-0000-0000-000000000003'
      and receiver_user_id = '15000000-0000-0000-0000-000000000001'
  ),
  'sent',
  'a successful retry terminally completes the dispatch'
);

create temporary table terminal_failure_claim as
select *
from public.claim_push_notification_dispatch(
  requested_notification_type => 'calendar_event_reminder',
  requested_source_id => '25000000-0000-0000-0000-000000000004',
  requested_receiver_user_id => '15000000-0000-0000-0000-000000000001',
  requested_title => 'Vinscent',
  requested_body => '오늘 일정이 있어요.',
  requested_data => '{}'::jsonb,
  requested_preference_column => null,
  requested_max_attempts => 1
);

select lives_ok(
  format(
    $sql$
      select public.complete_push_notification_delivery(
        'calendar_event_reminder',
        '25000000-0000-0000-0000-000000000004',
        '15000000-0000-0000-0000-000000000001',
        %L,
        1,
        0,
        1,
        'failed',
        'status=INVALID_ARGUMENT'
      )
    $sql$,
    (select claim_token from terminal_failure_claim)
  ),
  'the final failed attempt is recorded'
);

update public.push_notification_dispatches
set available_at = now() - interval '1 second'
where notification_type = 'calendar_event_reminder'
  and source_id = '25000000-0000-0000-0000-000000000004'
  and receiver_user_id = '15000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)
    from public.get_retryable_push_notification_dispatches(10)
    where source_id = '25000000-0000-0000-0000-000000000004'
  ),
  0::bigint,
  'a dispatch at its maximum attempt count is not retried'
);

select is(
  (
    select claim_result
    from public.claim_push_notification_dispatch(
      requested_notification_type => 'calendar_event_reminder',
      requested_source_id => '25000000-0000-0000-0000-000000000004',
      requested_receiver_user_id =>
        '15000000-0000-0000-0000-000000000001',
      requested_title => 'Vinscent',
      requested_body => '오늘 일정이 있어요.',
      requested_data => '{}'::jsonb,
      requested_preference_column => null,
      requested_max_attempts => 1
    )
  ),
  'duplicate',
  'a terminal failed dispatch cannot be claimed again'
);

create temporary table stale_processing_claim as
select *
from public.claim_push_notification_dispatch(
  requested_notification_type => 'calendar_event_reminder',
  requested_source_id => '25000000-0000-0000-0000-000000000005',
  requested_receiver_user_id => '15000000-0000-0000-0000-000000000001',
  requested_title => 'Vinscent',
  requested_body => '오늘 일정이 있어요.',
  requested_data => '{}'::jsonb,
  requested_preference_column => null,
  requested_max_attempts => 5
);

update public.push_notification_dispatches
set claimed_at = now() - interval '6 minutes'
where notification_type = 'calendar_event_reminder'
  and source_id = '25000000-0000-0000-0000-000000000005'
  and receiver_user_id = '15000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)
    from public.get_retryable_push_notification_dispatches(10)
    where source_id = '25000000-0000-0000-0000-000000000005'
  ),
  1::bigint,
  'a stale processing dispatch is recovered by the retry worker'
);

select is(
  (
    select attempt_count
    from public.claim_push_notification_dispatch(
      requested_notification_type => 'calendar_event_reminder',
      requested_source_id => '25000000-0000-0000-0000-000000000005',
      requested_receiver_user_id =>
        '15000000-0000-0000-0000-000000000001',
      requested_title => 'Vinscent',
      requested_body => '오늘 일정이 있어요.',
      requested_data => '{}'::jsonb,
      requested_preference_column => null,
      requested_max_attempts => 5
    )
  ),
  2,
  'reclaiming a stale dispatch advances its bounded attempt count'
);

select * from finish();
rollback;
