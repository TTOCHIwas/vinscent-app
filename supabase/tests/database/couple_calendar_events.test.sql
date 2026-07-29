begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(36);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '16000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'calendar-a@example.test',
    now(),
    now()
  ),
  (
    '16000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'calendar-b@example.test',
    now(),
    now()
  ),
  (
    '16000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'calendar-outsider@example.test',
    now(),
    now()
  );

insert into public.user_policy_acceptances (
  user_id,
  policy_type,
  policy_version
)
values
  (
    '16000000-0000-0000-0000-000000000001',
    'ugc_safety_policy',
    'ugc-safety-v1'
  ),
  (
    '16000000-0000-0000-0000-000000000002',
    'ugc_safety_policy',
    'ugc-safety-v1'
  );

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  user_b_id,
  relationship_start_date,
  timezone,
  status,
  connected_at
)
values (
  '26000000-0000-0000-0000-000000000001',
  'CALTEST',
  '16000000-0000-0000-0000-000000000001',
  '16000000-0000-0000-0000-000000000002',
  '2024-01-01',
  'Asia/Seoul',
  'active',
  now()
);

create temp table calendar_test_context on commit drop as
with context_date as (
  select timezone('Asia/Seoul', clock_timestamp())::date + 30 as event_date
)
select
  event_date,
  ((event_date + time '09:05') at time zone 'Asia/Seoul') as due_run_at
from context_date;

grant select on calendar_test_context to authenticated;

select has_table(
  'public',
  'couple_calendar_events',
  'shared calendar events are persisted separately'
);

select has_table(
  'public',
  'couple_calendar_event_reminders',
  'calendar reminders are persisted per user'
);

select has_function(
  'public',
  'save_couple_calendar_event',
  array[
    'uuid',
    'text',
    'date',
    'text',
    'text',
    'uuid',
    'boolean',
    'boolean',
    'integer',
    'time without time zone',
    'integer'
  ],
  'calendar writes use one authenticated boundary'
);

select set_config(
  'request.jwt.claim.sub',
  '16000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select lives_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '36000000-0000-0000-0000-000000000001',
      '  첫 여행  ',
      (select event_date from calendar_test_context),
      'none',
      '준비물 챙기기',
      null,
      false,
      true,
      0,
      '09:00',
      null
    )
  $$,
  'one member can create a shared event and personal reminder'
);

select throws_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '36000000-0000-0000-0000-000000000004',
      '이미 지난 알림',
      timezone('Asia/Seoul', clock_timestamp())::date,
      'none',
      null,
      null,
      false,
      true,
      0,
      '00:00',
      null
    )
  $$,
  'P0001',
  'calendar_event_reminder_in_past',
  'a reminder whose scheduled instant has passed is rejected'
);

reset role;

select is(
  (
    select title
    from public.couple_calendar_events
    where id = '36000000-0000-0000-0000-000000000001'
  ),
  '첫 여행',
  'event titles are normalized'
);

select is(
  (
    select revision
    from public.couple_calendar_events
    where id = '36000000-0000-0000-0000-000000000001'
  ),
  1,
  'new events start at revision one'
);

select results_eq(
  $$
    select is_enabled, offset_days, reminder_time
    from public.couple_calendar_event_reminders
    where event_id = '36000000-0000-0000-0000-000000000001'
      and user_id = '16000000-0000-0000-0000-000000000001'
  $$,
  $$ values (true, 0, '09:00'::time) $$,
  'the creator reminder belongs only to that user'
);

set local role authenticated;

select results_eq(
  $$
    select occurrence_date, title, own_reminder_enabled
    from public.get_couple_calendar_event_occurrences(
      (select event_date from calendar_test_context),
      (select event_date from calendar_test_context)
    )
  $$,
  $$
    select event_date, '첫 여행'::text, true
    from calendar_test_context
  $$,
  'the creator reads the event occurrence and own reminder'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '16000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select results_eq(
  $$
    select occurrence_date, title, own_reminder_enabled
    from public.get_couple_calendar_event_occurrences(
      (select event_date from calendar_test_context),
      (select event_date from calendar_test_context)
    )
  $$,
  $$
    select event_date, '첫 여행'::text, false
    from calendar_test_context
  $$,
  'the partner reads the shared event without seeing the creator reminder'
);

select lives_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '36000000-0000-0000-0000-000000000001',
      '윤년 여행',
      '2024-02-29',
      'yearly',
      null,
      null,
      false,
      true,
      1,
      '18:30',
      1
    )
  $$,
  'the partner can edit the shared event and configure a reminder'
);

reset role;

select is(
  (
    select revision
    from public.couple_calendar_events
    where id = '36000000-0000-0000-0000-000000000001'
  ),
  2,
  'editing increments the event revision'
);

select is(
  (
    select count(*)
    from public.couple_calendar_event_reminders
    where event_id = '36000000-0000-0000-0000-000000000001'
      and is_enabled
  ),
  2::bigint,
  'each member keeps an independent reminder'
);

insert into public.couple_calendar_events (
  id,
  couple_id,
  title,
  event_date,
  repeat_rule,
  created_by_user_id,
  updated_by_user_id
)
values (
  '36000000-0000-0000-0000-000000000005',
  '26000000-0000-0000-0000-000000000001',
  '지난 반복 일정',
  '2024-03-01',
  'yearly',
  '16000000-0000-0000-0000-000000000001',
  '16000000-0000-0000-0000-000000000001'
);

insert into public.couple_calendar_event_reminders (
  event_id,
  couple_id,
  user_id,
  is_enabled,
  offset_days,
  reminder_time
)
values (
  '36000000-0000-0000-0000-000000000005',
  '26000000-0000-0000-0000-000000000001',
  '16000000-0000-0000-0000-000000000001',
  true,
  0,
  '09:00'
);

update public.couple_calendar_events
set repeat_rule = 'none'
where id = '36000000-0000-0000-0000-000000000005';

select is(
  (
    select is_enabled
    from public.couple_calendar_event_reminders
    where event_id = '36000000-0000-0000-0000-000000000005'
      and user_id = '16000000-0000-0000-0000-000000000001'
  ),
  false,
  'changing an event disables reminders whose instant is already past'
);

set local role authenticated;

select results_eq(
  $$
    select occurrence_date, title
    from public.get_couple_calendar_event_occurrences(
      '2027-02-01',
      '2027-02-28'
    )
  $$,
  $$ values ('2027-02-28'::date, '윤년 여행'::text) $$,
  'a February 29 yearly event falls on February 28 in non-leap years'
);

select throws_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '36000000-0000-0000-0000-000000000002',
      '시작 전 일정',
      '2023-12-31',
      'none',
      null,
      null,
      false,
      false,
      0,
      '09:00',
      null
    )
  $$,
  'P0001',
  'calendar_event_before_relationship_start',
  'events before the relationship start date are rejected'
);

select throws_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '36000000-0000-0000-0000-000000000002',
      '지원 범위 밖 일정',
      '2101-01-01',
      'none',
      null,
      null,
      false,
      false,
      0,
      '09:00',
      null
    )
  $$,
  'P0001',
  'invalid_calendar_event_date',
  'events after the shared calendar range are rejected'
);

select throws_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '36000000-0000-0000-0000-000000000002',
      repeat('가', 31),
      '2026-08-01',
      'none',
      null,
      null,
      false,
      false,
      0,
      '09:00',
      null
    )
  $$,
  'P0001',
  'invalid_calendar_event_title',
  'event titles are limited to thirty characters'
);

select throws_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '36000000-0000-0000-0000-000000000002',
      '긴 메모',
      '2026-08-01',
      'none',
      repeat('가', 501),
      null,
      false,
      false,
      0,
      '09:00',
      null
    )
  $$,
  'P0001',
  'invalid_calendar_event_memo',
  'event memos are limited to five hundred characters'
);

insert into storage.objects (bucket_id, name)
values
  (
    'couple-calendar-artworks',
    '26000000-0000-0000-0000-000000000001/events/36000000-0000-0000-0000-000000000001/artworks/46000000-0000-0000-0000-000000000001/preview.webp'
  ),
  (
    'couple-calendar-artworks',
    '26000000-0000-0000-0000-000000000001/events/36000000-0000-0000-0000-000000000001/artworks/46000000-0000-0000-0000-000000000001/drawing.json.gz'
  );

select lives_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '36000000-0000-0000-0000-000000000001',
      '윤년 여행',
      '2024-02-29',
      'yearly',
      null,
      '46000000-0000-0000-0000-000000000001',
      false,
      true,
      1,
      '18:30',
      2
    )
  $$,
  'an uploaded drawing revision can be attached atomically'
);

reset role;

select results_eq(
  $$
    select
      artwork_preview_path,
      artwork_data_path
    from public.couple_calendar_events
    where id = '36000000-0000-0000-0000-000000000001'
  $$,
  $$
    values (
      '26000000-0000-0000-0000-000000000001/events/36000000-0000-0000-0000-000000000001/artworks/46000000-0000-0000-0000-000000000001/preview.webp'::text,
      '26000000-0000-0000-0000-000000000001/events/36000000-0000-0000-0000-000000000001/artworks/46000000-0000-0000-0000-000000000001/drawing.json.gz'::text
    )
  $$,
  'both artwork pointers switch together'
);

set local role authenticated;

select lives_ok(
  $$
    select public.discard_uploaded_couple_calendar_event_artwork(
      '36000000-0000-0000-0000-000000000001',
      '46000000-0000-0000-0000-000000000001'
    )
  $$,
  'discard is safe for the currently referenced drawing'
);

reset role;

select is(
  (
    select count(*)
    from public.storage_cleanup_requests
    where cleanup_reason = 'orphan_calendar_artwork'
  ),
  0::bigint,
  'discard never queues the current drawing'
);

set local role authenticated;

select lives_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '36000000-0000-0000-0000-000000000001',
      '알림 일정',
      (select event_date from calendar_test_context),
      'none',
      null,
      null,
      true,
      true,
      0,
      '09:00',
      3
    )
  $$,
  'removing a drawing preserves the event'
);

reset role;

select is(
  (
    select count(*)
    from public.storage_cleanup_requests
    where cleanup_reason = 'orphan_calendar_artwork'
  ),
  2::bigint,
  'removing a drawing queues both immutable artifacts'
);

select is(
  (
    select count(*)
    from public.get_due_couple_calendar_event_reminders(
      (select due_run_at from calendar_test_context),
      10
    )
    where event_id = '36000000-0000-0000-0000-000000000001'
      and receiver_user_id = '16000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'the scheduler resolves reminder time in the couple timezone'
);

select is(
  (
    select count(*)
    from public.get_due_couple_calendar_event_reminders(
      (select due_run_at from calendar_test_context),
      10,
      1
    )
  ),
  1::bigint,
  'the scheduler bounds each reminder batch'
);

select is(
  (
    select source_id
    from public.get_due_couple_calendar_event_reminders(
      (select due_run_at from calendar_test_context),
      10
    )
    where event_id = '36000000-0000-0000-0000-000000000001'
      and receiver_user_id = '16000000-0000-0000-0000-000000000002'
  ),
  (
    select source_id
    from public.get_due_couple_calendar_event_reminders(
      (select due_run_at + interval '1 minute' from calendar_test_context),
      10
    )
    where event_id = '36000000-0000-0000-0000-000000000001'
      and receiver_user_id = '16000000-0000-0000-0000-000000000002'
  ),
  'the same occurrence has a stable notification source id'
);

select is(
  (
    select count(*)
    from public.get_due_couple_calendar_event_reminders(
      (select due_run_at + interval '20 minutes' from calendar_test_context),
      10
    )
    where event_id = '36000000-0000-0000-0000-000000000001'
      and receiver_user_id = '16000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'an undispatched reminder remains recoverable after the polling lookback'
);

select is(
  (
    select count(*)
    from public.get_due_couple_calendar_event_reminders(
      (select due_run_at + interval '1 day' from calendar_test_context),
      10
    )
    where event_id = '36000000-0000-0000-0000-000000000001'
      and receiver_user_id = '16000000-0000-0000-0000-000000000002'
  ),
  0::bigint,
  'a missed one-time reminder is not delivered after the event date'
);

select set_config(
  'request.jwt.claim.sub',
  '16000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;

select throws_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '36000000-0000-0000-0000-000000000003',
      '외부 일정',
      '2026-08-01',
      'none',
      null,
      null,
      false,
      false,
      0,
      '09:00',
      null
    )
  $$,
  'P0001',
  'active_couple_required',
  'a non-member cannot write a shared event'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '16000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select lives_ok(
  $$
    select public.delete_couple_calendar_event(
      '36000000-0000-0000-0000-000000000001',
      4
    )
  $$,
  'either member can delete the shared event'
);

reset role;

select is(
  (
    select count(*)
    from public.couple_calendar_events
    where id = '36000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'deleting an event removes it from the shared calendar'
);

select ok(
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'couple_calendar_events'
  ),
  'shared event changes are published for realtime refresh'
);

select has_function(
  'private',
  'broadcast_couple_calendar_event_change',
  'calendar event changes have a database broadcast function'
);

select has_trigger(
  'public',
  'couple_calendar_events',
  'broadcast_couple_calendar_event_change',
  'calendar event inserts, updates, and deletes are broadcast'
);

select * from finish();
rollback;
