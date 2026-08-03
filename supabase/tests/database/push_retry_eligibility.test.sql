begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(7);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '15000000-0000-0000-0000-000000000031',
    'authenticated',
    'authenticated',
    'retry-a@example.test',
    now(),
    now()
  ),
  (
    '15000000-0000-0000-0000-000000000032',
    'authenticated',
    'authenticated',
    'retry-b@example.test',
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
  '25000000-0000-0000-0000-000000000031',
  'RETRY1',
  '15000000-0000-0000-0000-000000000031',
  '15000000-0000-0000-0000-000000000032',
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
values (
  '35000000-0000-0000-0000-000000000031',
  '25000000-0000-0000-0000-000000000031',
  current_date,
  'question_generated',
  now() - interval '2 hours',
  now() - interval '2 hours'
);

insert into public.daily_questions (
  id,
  couple_id,
  question_id,
  assigned_date,
  status,
  story_loop_id
)
select
  '45000000-0000-0000-0000-000000000031',
  '25000000-0000-0000-0000-000000000031',
  question.id,
  current_date,
  'pending',
  '35000000-0000-0000-0000-000000000031'
from public.questions as question
where question.curriculum_version = 1
  and question.curriculum_position = 1;

select is(
  public.is_push_notification_retry_eligible(
    'recording_activity',
    '55000000-0000-0000-0000-000000000031',
    '15000000-0000-0000-0000-000000000032',
    '{}'::jsonb
  ),
  true,
  'notification types without expiring source state remain retryable'
);

select is(
  public.is_push_notification_retry_eligible(
    'unanswered_reminder',
    '45000000-0000-0000-0000-000000000031',
    '15000000-0000-0000-0000-000000000032',
    '{}'::jsonb
  ),
  true,
  'an unanswered active question remains retryable'
);

insert into public.daily_question_answers (
  daily_question_id,
  user_id,
  answer_text
)
values (
  '45000000-0000-0000-0000-000000000031',
  '15000000-0000-0000-0000-000000000032',
  '답변'
);

select is(
  public.is_push_notification_retry_eligible(
    'unanswered_reminder',
    '45000000-0000-0000-0000-000000000031',
    '15000000-0000-0000-0000-000000000032',
    '{}'::jsonb
  ),
  false,
  'an answered question is not retried'
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
  '55000000-0000-0000-0000-000000000031',
  '25000000-0000-0000-0000-000000000031',
  '함께할 일정',
  current_date + 2,
  'none',
  '15000000-0000-0000-0000-000000000031',
  '15000000-0000-0000-0000-000000000031'
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
  '55000000-0000-0000-0000-000000000031',
  '25000000-0000-0000-0000-000000000031',
  '15000000-0000-0000-0000-000000000032',
  true,
  1,
  '09:00'
);

select is(
  public.is_push_notification_retry_eligible(
    'calendar_event_reminder',
    md5(
      '55000000-0000-0000-0000-000000000031'
      || ':15000000-0000-0000-0000-000000000032:'
      || (current_date + 2)::text
    )::uuid,
    '15000000-0000-0000-0000-000000000032',
    jsonb_build_object(
      'event_id',
      '55000000-0000-0000-0000-000000000031',
      'event_date',
      (current_date + 2)::text
    )
  ),
  true,
  'an enabled current calendar reminder remains retryable'
);

create temporary table exhausted_calendar_claim as
select *
from public.claim_push_notification_dispatch(
  requested_notification_type => 'calendar_event_reminder',
  requested_source_id => md5(
    '55000000-0000-0000-0000-000000000031'
    || ':15000000-0000-0000-0000-000000000032:'
    || (current_date + 2)::text
  )::uuid,
  requested_receiver_user_id => '15000000-0000-0000-0000-000000000032',
  requested_title => 'Vinscent',
  requested_body => '일정 알림',
  requested_data => jsonb_build_object(
    'event_id',
    '55000000-0000-0000-0000-000000000031',
    'event_date',
    (current_date + 2)::text
  ),
  requested_preference_column => null,
  requested_max_attempts => 1
);

update public.push_notification_dispatches
set claimed_at = now() - interval '6 minutes'
where notification_type = 'calendar_event_reminder'
  and source_id = (
    select source_id
    from exhausted_calendar_claim
  )
  and receiver_user_id = '15000000-0000-0000-0000-000000000032';

select is(
  (
    select count(*)
    from public.get_due_couple_calendar_event_reminders(
      (current_date + time '10:00') at time zone 'UTC',
      10,
      100
    )
    where event_id = '55000000-0000-0000-0000-000000000031'
      and receiver_user_id = '15000000-0000-0000-0000-000000000032'
  ),
  0::bigint,
  'calendar backlog loading never competes with an existing retry lifecycle'
);

update public.couple_calendar_event_reminders
set is_enabled = false
where event_id = '55000000-0000-0000-0000-000000000031'
  and user_id = '15000000-0000-0000-0000-000000000032';

select is(
  public.is_push_notification_retry_eligible(
    'calendar_event_reminder',
    md5(
      '55000000-0000-0000-0000-000000000031'
      || ':15000000-0000-0000-0000-000000000032:'
      || (current_date + 2)::text
    )::uuid,
    '15000000-0000-0000-0000-000000000032',
    jsonb_build_object(
      'event_id',
      '55000000-0000-0000-0000-000000000031',
      'event_date',
      (current_date + 2)::text
    )
  ),
  false,
  'a disabled calendar reminder is not retried'
);

delete from public.couple_calendar_events
where id = '55000000-0000-0000-0000-000000000031';

select is(
  public.is_push_notification_retry_eligible(
    'calendar_event_reminder',
    md5(
      '55000000-0000-0000-0000-000000000031'
      || ':15000000-0000-0000-0000-000000000032:'
      || (current_date + 2)::text
    )::uuid,
    '15000000-0000-0000-0000-000000000032',
    jsonb_build_object(
      'event_id',
      '55000000-0000-0000-0000-000000000031',
      'event_date',
      (current_date + 2)::text
    )
  ),
  false,
  'a deleted calendar event is not retried'
);

select * from finish();
rollback;
