begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(5);

create temporary table reminder_test_clock as
select date_trunc('minute', now()) as run_at;

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '15000000-0000-0000-0000-000000000021',
    'authenticated',
    'authenticated',
    'reminder-a@example.test',
    now(),
    now()
  ),
  (
    '15000000-0000-0000-0000-000000000022',
    'authenticated',
    'authenticated',
    'reminder-b@example.test',
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
  '25000000-0000-0000-0000-000000000021',
  'REMIND',
  '15000000-0000-0000-0000-000000000021',
  '15000000-0000-0000-0000-000000000022',
  current_date - 30,
  'UTC',
  'active',
  now()
);

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status,
  question_generated_at,
  story_edit_locked_at
)
select
  '35000000-0000-0000-0000-000000000021',
  '25000000-0000-0000-0000-000000000021',
  (run_at at time zone 'UTC')::date,
  'question_generated',
  run_at - interval '2 hours',
  run_at - interval '2 hours'
from reminder_test_clock;

insert into public.daily_questions (
  id,
  couple_id,
  question_id,
  assigned_date,
  status,
  story_loop_id
)
select
  '45000000-0000-0000-0000-000000000021',
  '25000000-0000-0000-0000-000000000021',
  question.id,
  story_loop.couple_date,
  'pending',
  story_loop.id
from public.questions as question
cross join public.daily_story_loops as story_loop
where question.curriculum_version = 1
  and question.curriculum_position = 1
  and story_loop.id = '35000000-0000-0000-0000-000000000021';

select is(
  (
    select count(*)
    from public.get_due_unanswered_question_reminders(
      (select run_at from reminder_test_clock),
      100
    )
  ),
  2::bigint,
  'an overdue question remains discoverable after the old lookback window'
);

insert into public.daily_question_answers (
  daily_question_id,
  user_id,
  answer_text
)
values (
  '45000000-0000-0000-0000-000000000021',
  '15000000-0000-0000-0000-000000000021',
  '답변'
);

select results_eq(
  $$
    select receiver_user_id
    from public.get_due_unanswered_question_reminders(
      (select run_at from reminder_test_clock),
      100
    )
  $$,
  $$
    values ('15000000-0000-0000-0000-000000000022'::uuid)
  $$,
  'a member who already answered is excluded'
);

insert into public.user_notification_preferences (
  user_id,
  reminder_enabled
)
values (
  '15000000-0000-0000-0000-000000000022',
  false
);

select is(
  (
    select count(*)
    from public.get_due_unanswered_question_reminders(
      (select run_at from reminder_test_clock),
      100
    )
  ),
  0::bigint,
  'a member who disabled reminders is excluded'
);

update public.user_notification_preferences
set reminder_enabled = true
where user_id = '15000000-0000-0000-0000-000000000022';

create temporary table existing_reminder_claim as
select *
from public.claim_push_notification_dispatch(
  requested_notification_type => 'unanswered_reminder',
  requested_source_id => '45000000-0000-0000-0000-000000000021',
  requested_receiver_user_id => '15000000-0000-0000-0000-000000000022',
  requested_title => 'Vinscent',
  requested_body => '답변을 기다리고 있어요',
  requested_data => '{}'::jsonb,
  requested_preference_column => 'reminder_enabled',
  requested_max_attempts => 5
);

select is(
  (
    select count(*)
    from public.get_due_unanswered_question_reminders(
      (select run_at from reminder_test_clock),
      100
    )
  ),
  0::bigint,
  'an existing dispatch remains owned by the dispatch lifecycle'
);

delete from public.push_notification_dispatches
where notification_type = 'unanswered_reminder'
  and source_id = '45000000-0000-0000-0000-000000000021'
  and receiver_user_id = '15000000-0000-0000-0000-000000000022';

select is(
  (
    select count(*)
    from public.get_due_unanswered_question_reminders(
      (select run_at from reminder_test_clock),
      1
    )
  ),
  1::bigint,
  'the due reminder query respects its bounded batch size'
);

select * from finish();
rollback;
