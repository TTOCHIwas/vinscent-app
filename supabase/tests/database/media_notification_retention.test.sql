begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(6);

create temp table fixture as
select gen_random_uuid() as sender, gen_random_uuid() as receiver,
  gen_random_uuid() as couple, gen_random_uuid() as story;

insert into auth.users (id) select sender from fixture union all select receiver from fixture;
insert into public.couples (id, invite_code, user_a_id, user_b_id, status, character_setup_status)
select couple, 'NRET01', sender, receiver, 'active', 'default' from fixture;
insert into public.daily_story_loops (id, couple_id, couple_date, status)
select story, couple, current_date, 'question_generated' from fixture;

insert into public.recording_notification_events (couple_id, sender_user_id, receiver_user_id, event_type, slot_title, created_at)
select couple, sender, receiver, 'slot_saved', label, now() - age from fixture
cross join (values ('old', interval '91 days'), ('boundary', interval '90 days'),
  ('retry', interval '91 days'), ('processing', interval '91 days')) f(label, age);
insert into public.story_loop_notification_events (couple_id, story_loop_id, sender_user_id, receiver_user_id, event_type, created_at)
select couple, story, sender, receiver, kind, now() - age from fixture
cross join (values ('question_generated', interval '91 days'),
  ('partner_story_card_uploaded', interval '91 days'), ('partner_story_card_uploaded', interval '90 days')) f(kind, age);
insert into public.push_notification_dispatches
  (notification_type, source_id, receiver_user_id, status, attempt_count, max_attempts)
select 'recording_activity', id, receiver_user_id,
  case slot_title when 'retry' then 'failed' else 'processing' end, 1, 2
from public.recording_notification_events where couple_id = (select couple from fixture)
  and slot_title in ('retry', 'processing');

insert into net.http_request_queue (method, url, timeout_milliseconds)
values ('POST', 'https://retention.invalid/send-recording-notification', 1000),
  ('POST', 'https://retention.invalid/send-story-loop-notification', 1000);
select * from private.purge_expired_media_notification_events();
select is((select count(*) from public.recording_notification_events where couple_id = (select couple from fixture)),
  4::bigint, 'retain recordings while their webhook is queued');
select is((select count(*) from public.story_loop_notification_events where couple_id = (select couple from fixture)),
  3::bigint, 'retain cards while their webhook is queued');

delete from net.http_request_queue where url like 'https://retention.invalid/%';
select * from private.purge_expired_media_notification_events();
select results_eq($q$select slot_title from public.recording_notification_events
  where couple_id = (select couple from fixture) order by slot_title$q$,
  $$values ('boundary'), ('processing'), ('retry')$$, 'preserve the boundary and unfinished recording dispatches');
select results_eq($q$select event_type, created_at = now() - interval '90 days'
  from public.story_loop_notification_events where couple_id = (select couple from fixture) order by event_type$q$,
  $$values ('partner_story_card_uploaded', true), ('question_generated', false)$$,
  'preserve the boundary and old question deduplication records');
select ok(not has_function_privilege('authenticated','private.purge_expired_media_notification_events()', 'execute'),
  'app users cannot run cleanup');
select ok((select command like '%private.purge_expired_operational_records()%'
    and command like '%private.purge_completed_storage_cleanup_requests()%'
    and command like '%private.purge_expired_media_notification_events()%'
    and has_function_privilege(username, 'private.purge_expired_media_notification_events()', 'execute')
    from cron.job where jobname = 'purge-expired-operational-records'), 'daily job runs all retention functions');
select * from finish();
rollback;
