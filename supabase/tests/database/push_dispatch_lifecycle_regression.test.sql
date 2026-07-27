begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(5);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values (
  '15000000-0000-0000-0000-000000000011',
  'authenticated',
  'authenticated',
  'push-lifecycle@example.test',
  now(),
  now()
);

create temporary table exhausted_claim as
select *
from public.claim_push_notification_dispatch(
  requested_notification_type => 'calendar_event_reminder',
  requested_source_id => '25000000-0000-0000-0000-000000000011',
  requested_receiver_user_id => '15000000-0000-0000-0000-000000000011',
  requested_title => 'Vinscent',
  requested_body => '일정 알림',
  requested_data => '{}'::jsonb,
  requested_preference_column => null,
  requested_max_attempts => 1
);

select is(
  (select attempt_count from exhausted_claim),
  1,
  'the final allowed attempt is claimed'
);

update public.push_notification_dispatches
set claimed_at = now() - interval '6 minutes'
where notification_type = 'calendar_event_reminder'
  and source_id = '25000000-0000-0000-0000-000000000011'
  and receiver_user_id = '15000000-0000-0000-0000-000000000011';

select is(
  public.finalize_exhausted_push_notification_dispatches(10),
  1,
  'a stale dispatch at its attempt limit is finalized'
);

select results_eq(
  $$
    select status, completed_at is not null
    from public.push_notification_dispatches
    where notification_type = 'calendar_event_reminder'
      and source_id = '25000000-0000-0000-0000-000000000011'
      and receiver_user_id = '15000000-0000-0000-0000-000000000011'
  $$,
  $$ values ('failed'::text, true) $$,
  'the abandoned final attempt reaches a terminal state'
);

select results_eq(
  $$
    select status, target_token_count, success_count, failure_count
    from public.push_notification_deliveries
    where notification_type = 'calendar_event_reminder'
      and source_id = '25000000-0000-0000-0000-000000000011'
      and receiver_user_id = '15000000-0000-0000-0000-000000000011'
  $$,
  $$ values ('failed'::text, 0, 0, 0) $$,
  'terminal recovery records the unknown delivery outcome'
);

select is(
  (
    select count(*)
    from public.get_retryable_push_notification_dispatches(10)
    where source_id = '25000000-0000-0000-0000-000000000011'
  ),
  0::bigint,
  'the finalized dispatch no longer occupies the retry queue'
);

select * from finish();
rollback;
