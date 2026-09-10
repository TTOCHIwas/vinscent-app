begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(21);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  ('7b000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'carry-a@example.test', now(), now()),
  ('7b000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'carry-b@example.test', now(), now()),
  ('7b000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'due-a@example.test', now(), now()),
  ('7b000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'due-b@example.test', now(), now()),
  ('7b000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'same-day-a@example.test', now(), now()),
  ('7b000000-0000-0000-0000-000000000006', 'authenticated', 'authenticated', 'same-day-b@example.test', now(), now()),
  ('7b000000-0000-0000-0000-000000000007', 'authenticated', 'authenticated', 'early-a@example.test', now(), now()),
  ('7b000000-0000-0000-0000-000000000008', 'authenticated', 'authenticated', 'early-b@example.test', now(), now());

insert into public.user_policy_acceptances (
  user_id,
  policy_type,
  policy_version
)
select
  users.id,
  'ugc_safety_policy',
  'ugc-safety-v1'
from auth.users as users
where users.id between
  '7b000000-0000-0000-0000-000000000001'::uuid
  and '7b000000-0000-0000-0000-000000000008'::uuid;

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  user_b_id,
  relationship_start_date,
  question_delivery_time,
  question_delivery_time_set_at,
  timezone,
  status,
  connected_at,
  character_setup_status
)
values
  (
    '7c000000-0000-0000-0000-000000000001',
    'CARRY001',
    '7b000000-0000-0000-0000-000000000001',
    '7b000000-0000-0000-0000-000000000002',
    current_date - 30,
    '09:00:00',
    now(),
    'UTC',
    'active',
    now(),
    'default'
  ),
  (
    '7c000000-0000-0000-0000-000000000002',
    'CARRY002',
    '7b000000-0000-0000-0000-000000000003',
    '7b000000-0000-0000-0000-000000000004',
    current_date - 30,
    '00:00:00',
    now(),
    'UTC',
    'active',
    now(),
    'default'
  ),
  (
    '7c000000-0000-0000-0000-000000000003',
    'CARRY003',
    '7b000000-0000-0000-0000-000000000005',
    '7b000000-0000-0000-0000-000000000006',
    current_date - 30,
    '00:00:00',
    now(),
    'UTC',
    'active',
    now(),
    'default'
  ),
  (
    '7c000000-0000-0000-0000-000000000004',
    'CARRY004',
    '7b000000-0000-0000-0000-000000000007',
    '7b000000-0000-0000-0000-000000000008',
    current_date - 30,
    '23:00:00',
    now(),
    case
      when (now() at time zone 'UTC')::time < '20:00:00'::time then 'UTC'
      else 'America/Los_Angeles'
    end,
    'active',
    now(),
    'default'
  );

insert into public.questions (
  id,
  source,
  question_text,
  category,
  is_active
)
values
  ('7d000000-0000-0000-0000-000000000001', 'curated', '이월 질문 테스트 1', 'test', true),
  ('7d000000-0000-0000-0000-000000000002', 'curated', '이월 질문 테스트 2', 'test', true),
  ('7d000000-0000-0000-0000-000000000003', 'curated', '이월 질문 테스트 3', 'test', true);

insert into public.daily_questions (
  id,
  couple_id,
  question_id,
  assigned_date,
  status
)
values
  (
    '7e000000-0000-0000-0000-000000000001',
    '7c000000-0000-0000-0000-000000000001',
    '7d000000-0000-0000-0000-000000000001',
    current_date - 3,
    'pending'
  ),
  (
    '7e000000-0000-0000-0000-000000000002',
    '7c000000-0000-0000-0000-000000000002',
    '7d000000-0000-0000-0000-000000000002',
    current_date - 2,
    'answered_by_one'
  ),
  (
    '7e000000-0000-0000-0000-000000000003',
    '7c000000-0000-0000-0000-000000000004',
    '7d000000-0000-0000-0000-000000000003',
    (
      now() at time zone (
        select timezone
        from public.couples
        where id = '7c000000-0000-0000-0000-000000000004'
      )
    )::date - 2,
    'answered_by_one'
  );

insert into public.daily_question_answers (
  daily_question_id,
  user_id,
  answer_text
)
values
  (
    '7e000000-0000-0000-0000-000000000002',
    '7b000000-0000-0000-0000-000000000003',
    '먼저 남긴 답변'
  ),
  (
    '7e000000-0000-0000-0000-000000000003',
    '7b000000-0000-0000-0000-000000000007',
    '설정 시간 전 답변'
  );

select set_config(
  'request.jwt.claim.sub',
  '7b000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.get_daily_question_detail(null)),
  1::bigint,
  'the current question detail keeps an unresolved question from a prior day'
);
select is(
  (select couple_date from public.get_daily_question_detail(null)),
  current_date - 3,
  'the carried question preserves its original assigned date'
);
select is(
  (select can_answer_question from public.get_daily_question_detail(null)),
  true,
  'the carried question remains answerable'
);

reset role;
set local role service_role;

select is(
  (
    select count(*)
    from public.assign_due_daily_questions(
      date_trunc('day', now()) + interval '10 hours',
      100
    )
    where couple_id = '7c000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'an unresolved carried question blocks a new scheduled question'
);

reset role;

select is(
  (
    select count(*)
    from public.daily_questions
    where couple_id = '7c000000-0000-0000-0000-000000000001'
      and assigned_date = current_date
  ),
  0::bigint,
  'blocked days do not create catch-up questions'
);

select set_config(
  'request.jwt.claim.sub',
  '7b000000-0000-0000-0000-000000000004',
  true
);
set local role authenticated;

select lives_ok(
  $$select * from public.submit_daily_question_answer(
    '7e000000-0000-0000-0000-000000000002',
    '늦게 남긴 두 번째 답변'
  )$$,
  'a partner can complete a carried question after its assigned date'
);

reset role;

select is(
  (
    select status
    from public.daily_questions
    where id = '7e000000-0000-0000-0000-000000000002'
  ),
  'completed',
  'the carried question is completed normally'
);
select is(
  (
    select count(*)
    from public.daily_questions
    where couple_id = '7c000000-0000-0000-0000-000000000002'
      and assigned_date = current_date
  ),
  1::bigint,
  'completion after the delivery time immediately assigns today question'
);
select is(
  (
    select count(*)
    from public.daily_questions
    where couple_id = '7c000000-0000-0000-0000-000000000002'
  ),
  2::bigint,
  'multi-day carryover creates only the current-day successor'
);

select set_config(
  'request.jwt.claim.sub',
  '7b000000-0000-0000-0000-000000000004',
  true
);
set local role authenticated;

select is(
  (select couple_date from public.get_daily_question_detail(null)),
  current_date,
  'the newly assigned question becomes the current question immediately'
);

reset role;
set local role service_role;

select is(
  (
    select count(*)
    from public.assign_due_daily_questions(
      date_trunc('day', now()) + interval '10 hours',
      100
    )
    where couple_id = '7c000000-0000-0000-0000-000000000002'
  ),
  2::bigint,
  'the immediate successor remains queued for both delivery notifications'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '7b000000-0000-0000-0000-000000000008',
  true
);
set local role authenticated;

select lives_ok(
  $$select * from public.submit_daily_question_answer(
    '7e000000-0000-0000-0000-000000000003',
    '설정 시간 전에 마친 답변'
  )$$,
  'a carried question can also be completed before the delivery time'
);

reset role;

select is(
  (
    select count(*)
    from public.daily_questions as question
    join public.couples as couple on couple.id = question.couple_id
    where question.couple_id = '7c000000-0000-0000-0000-000000000004'
      and question.assigned_date
        = (now() at time zone couple.timezone)::date
  ),
  0::bigint,
  'completion before the delivery time waits without assigning immediately'
);

select set_config(
  'test.carryover_due_at',
  (
    select (
      (now() at time zone couple.timezone)::date
        + '23:30:00'::time
    ) at time zone couple.timezone
    from public.couples as couple
    where couple.id = '7c000000-0000-0000-0000-000000000004'
  )::text,
  true
);

set local role service_role;

select is(
  (
    select count(*)
    from public.assign_due_daily_questions(now(), 100)
    where couple_id = '7c000000-0000-0000-0000-000000000004'
  ),
  0::bigint,
  'the scheduler still waits while the configured local time has not arrived'
);
select is(
  (
    select count(*)
    from public.assign_due_daily_questions(
      current_setting('test.carryover_due_at')::timestamptz,
      100
    )
    where couple_id = '7c000000-0000-0000-0000-000000000004'
  ),
  2::bigint,
  'the next question is assigned when the configured time arrives'
);

reset role;
set local role service_role;

select is(
  (
    select count(*)
    from public.assign_due_daily_questions(
      date_trunc('day', now()) + interval '10 hours',
      100
    )
    where couple_id = '7c000000-0000-0000-0000-000000000003'
  ),
  2::bigint,
  'a due couple receives its first question without a card'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '7b000000-0000-0000-0000-000000000005',
  true
);
set local role authenticated;

select lives_ok(
  $$select * from public.submit_daily_question_answer(
    (
      select daily_question_id
      from public.get_daily_question_detail(null)
    ),
    '첫 번째 답변'
  )$$,
  'the first member can answer the same-day question'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '7b000000-0000-0000-0000-000000000006',
  true
);
set local role authenticated;

select lives_ok(
  $$select * from public.submit_daily_question_answer(
    (
      select daily_question_id
      from public.get_daily_question_detail(null)
    ),
    '두 번째 답변'
  )$$,
  'the second member can complete the same-day question'
);

reset role;

select is(
  (
    select status
    from public.daily_questions
    where couple_id = '7c000000-0000-0000-0000-000000000003'
      and assigned_date = current_date
  ),
  'completed',
  'the same-day question is completed'
);
select is(
  (
    select count(*)
    from public.daily_questions
    where couple_id = '7c000000-0000-0000-0000-000000000003'
      and assigned_date = current_date
  ),
  1::bigint,
  'same-day completion never assigns a second question'
);

select is(
  (
    select count(*)
    from public.daily_questions
    where couple_id = '7c000000-0000-0000-0000-000000000004'
  ),
  2::bigint,
  'waiting multiple days never backfills skipped dates'
);

select * from finish();
rollback;
