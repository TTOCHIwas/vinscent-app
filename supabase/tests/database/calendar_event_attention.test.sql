begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(4);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '16000000-0000-0000-0000-000000000011',
    'authenticated',
    'authenticated',
    'calendar-attention-a@example.test',
    now(),
    now()
  ),
  (
    '16000000-0000-0000-0000-000000000012',
    'authenticated',
    'authenticated',
    'calendar-attention-b@example.test',
    now(),
    now()
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
  '26000000-0000-0000-0000-000000000011',
  'CALATTN',
  '16000000-0000-0000-0000-000000000011',
  '16000000-0000-0000-0000-000000000012',
  '2024-01-01',
  'Asia/Seoul',
  'active',
  now()
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
values
  (
    '36000000-0000-0000-0000-000000000011',
    '26000000-0000-0000-0000-000000000011',
    '오늘 일정',
    '2026-09-05',
    'none',
    '16000000-0000-0000-0000-000000000011',
    '16000000-0000-0000-0000-000000000011'
  ),
  (
    '36000000-0000-0000-0000-000000000012',
    '26000000-0000-0000-0000-000000000011',
    '매년 일정',
    '2024-09-06',
    'yearly',
    '16000000-0000-0000-0000-000000000011',
    '16000000-0000-0000-0000-000000000011'
  );

select has_function(
  'public',
  'has_couple_calendar_event_occurrence',
  array['date'],
  'calendar attention has a lightweight occurrence lookup'
);

select set_config(
  'request.jwt.claim.sub',
  '16000000-0000-0000-0000-000000000011',
  true
);
set local role authenticated;

select is(
  public.has_couple_calendar_event_occurrence('2026-09-05'),
  true,
  'one-time events create attention on their event date'
);

select is(
  public.has_couple_calendar_event_occurrence('2026-09-06'),
  true,
  'yearly events create attention on their occurrence date'
);

select is(
  public.has_couple_calendar_event_occurrence('2026-09-07'),
  false,
  'dates without an occurrence do not create attention'
);

select * from finish();
rollback;
