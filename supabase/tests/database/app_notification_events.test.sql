begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '13000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'notification-user-a@example.test',
    now(),
    now()
  ),
  (
    '13000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'notification-user-b@example.test',
    now(),
    now()
  );

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  status,
  character_setup_status
)
values (
  '23000000-0000-0000-0000-000000000001',
  'NOTIFY',
  '13000000-0000-0000-0000-000000000001',
  'pending',
  'pending'
);

select set_config(
  'request.jwt.claim.sub',
  '13000000-0000-0000-0000-000000000002',
  true
);

update public.couples
set
  user_b_id = '13000000-0000-0000-0000-000000000002',
  status = 'active',
  connected_at = now()
where id = '23000000-0000-0000-0000-000000000001';

select is(
  (
    select receiver_user_id
    from public.app_notification_events
    where event_type = 'couple_setup_started'
      and couple_id = '23000000-0000-0000-0000-000000000001'
  ),
  '13000000-0000-0000-0000-000000000001'::uuid,
  'joining a couple notifies the waiting member that setup started'
);

insert into public.couple_characters (
  couple_id,
  image_path,
  drawing_data_path,
  updated_by
)
values (
  '23000000-0000-0000-0000-000000000001',
  '23000000-0000-0000-0000-000000000001/current.png',
  '23000000-0000-0000-0000-000000000001/current.json',
  '13000000-0000-0000-0000-000000000002'
);

select is(
  (
    select count(*)
    from public.app_notification_events
    where event_type = 'couple_character_updated'
      and couple_id = '23000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'initial character drawing does not send a separate update notification'
);

update public.couples
set
  relationship_start_date = current_date - 30,
  character_setup_status = 'custom'
where id = '23000000-0000-0000-0000-000000000001';

select is(
  (
    select receiver_user_id
    from public.app_notification_events
    where event_type = 'couple_setup_completed'
      and couple_id = '23000000-0000-0000-0000-000000000001'
  ),
  '13000000-0000-0000-0000-000000000001'::uuid,
  'finishing initial setup notifies the waiting member'
);

select set_config(
  'request.jwt.claim.sub',
  '13000000-0000-0000-0000-000000000001',
  true
);

update public.couple_characters
set updated_by = '13000000-0000-0000-0000-000000000001'
where couple_id = '23000000-0000-0000-0000-000000000001';

select is(
  (
    select receiver_user_id
    from public.app_notification_events
    where event_type = 'couple_character_updated'
      and couple_id = '23000000-0000-0000-0000-000000000001'
  ),
  '13000000-0000-0000-0000-000000000002'::uuid,
  'later character updates notify the partner'
);

update public.couples
set
  status = 'disconnected',
  disconnected_at = now(),
  disconnected_by_user_id = '13000000-0000-0000-0000-000000000001',
  archive_expires_at = now() + interval '30 days'
where id = '23000000-0000-0000-0000-000000000001';

select set_config(
  'request.jwt.claim.sub',
  '13000000-0000-0000-0000-000000000002',
  true
);

update public.couples
set
  status = 'active',
  connected_at = now(),
  disconnected_at = null,
  disconnected_by_user_id = null,
  archive_expires_at = null
where id = '23000000-0000-0000-0000-000000000001';

select is(
  (
    select receiver_user_id
    from public.app_notification_events
    where event_type = 'couple_reconnected'
      and couple_id = '23000000-0000-0000-0000-000000000001'
  ),
  '13000000-0000-0000-0000-000000000001'::uuid,
  'reconnecting notifies the other member'
);

set local role authenticated;

select is(
  (
    select couple_activity_enabled
    from public.get_my_notification_preferences()
  ),
  true,
  'couple activity notifications default to enabled'
);

select is(
  (
    select ai_updates_enabled
    from public.get_my_notification_preferences()
  ),
  true,
  'character update notifications default to enabled'
);

select is(
  (
    select couple_activity_enabled
    from public.update_my_notification_preferences(
      true,
      true,
      true,
      true,
      true,
      true,
      false,
      false
    )
  ),
  false,
  'couple activity notification preference can be disabled'
);

select is(
  (
    select ai_updates_enabled
    from public.get_my_notification_preferences()
  ),
  false,
  'character update notification preference is persisted'
);

reset role;

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status,
  question_generated_at,
  story_edit_locked_at
)
values (
  '33000000-0000-0000-0000-000000000001',
  '23000000-0000-0000-0000-000000000001',
  current_date,
  'completed',
  now(),
  now()
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
  '43000000-0000-0000-0000-000000000001',
  '23000000-0000-0000-0000-000000000001',
  q.id,
  current_date,
  'completed',
  '33000000-0000-0000-0000-000000000001'
from public.questions as q
where q.curriculum_version = 1
  and q.curriculum_position = 1;

insert into public.ai_runs (
  id,
  couple_id,
  daily_question_id,
  task,
  provider,
  model,
  prompt_version,
  status,
  input_answer_ids,
  safety_status,
  completed_at
)
values (
  '63000000-0000-0000-0000-000000000001',
  '23000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000001',
  'generate_feedback',
  'fixture',
  'fixture',
  'feedback-test',
  'succeeded',
  '{}',
  'passed',
  now()
);

insert into public.ai_question_feedbacks (
  daily_question_id,
  couple_id,
  feedback_text,
  state,
  safety_status,
  source_run_id,
  published_at
)
values (
  '43000000-0000-0000-0000-000000000001',
  '23000000-0000-0000-0000-000000000001',
  '두 사람 모두 오늘의 작은 순간을 소중하게 봤네.',
  'published',
  'passed',
  '63000000-0000-0000-0000-000000000001',
  now()
);

select is(
  (
    select count(*)
    from public.app_notification_events
    where event_type = 'ai_feedback_ready'
      and daily_question_id = '43000000-0000-0000-0000-000000000001'
  ),
  2::bigint,
  'published feedback creates one notification event per member'
);

select is(
  (
    select count(distinct payload->>'assigned_date')
    from public.app_notification_events
    where event_type = 'ai_feedback_ready'
      and daily_question_id = '43000000-0000-0000-0000-000000000001'
  ),
  1::bigint,
  'feedback events include the assigned date for navigation'
);

update public.ai_question_feedbacks
set feedback_text = '같은 피드백을 다시 저장해도 알림은 늘어나지 않아.'
where daily_question_id = '43000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)
    from public.app_notification_events
    where event_type = 'ai_feedback_ready'
      and daily_question_id = '43000000-0000-0000-0000-000000000001'
  ),
  2::bigint,
  'editing the same published feedback does not duplicate notifications'
);

select * from finish();
rollback;
