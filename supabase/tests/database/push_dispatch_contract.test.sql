begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);

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

select * from finish();
rollback;
