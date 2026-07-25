begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);

insert into auth.users (
  id,
  aud,
  role,
  email,
  created_at,
  updated_at
)
values
  (
    '17000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'ai-notification-user-a@example.test',
    now(),
    now()
  ),
  (
    '17000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-notification-user-b@example.test',
    now(),
    now()
  );

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  user_b_id,
  relationship_start_date,
  status,
  connected_at,
  character_setup_status
)
values (
  '27000000-0000-0000-0000-000000000001',
  'AINOTIFY',
  '17000000-0000-0000-0000-000000000001',
  '17000000-0000-0000-0000-000000000002',
  current_date - 10,
  'active',
  now(),
  'default'
);

insert into public.ai_user_consents (
  couple_id,
  user_id,
  status,
  policy_version,
  granted_at,
  revoked_at
)
values
  (
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    'granted',
    'ai-learning-v1',
    now(),
    null
  ),
  (
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000002',
    'granted',
    'ai-learning-v1',
    now(),
    null
  );

insert into public.ai_feature_entitlements (
  couple_id,
  feature_key,
  source
)
values (
  '27000000-0000-0000-0000-000000000001',
  'focused_questions',
  'test_unlock'
);

select ok(
  exists (
    select 1
    from pg_trigger as pt
    where pt.tgname = 'ai_focused_answers_notify_partner_waiting'
      and not pt.tgisinternal
  ),
  'focused answers have a partner waiting notification trigger'
);
select ok(
  exists (
    select 1
    from pg_trigger as pt
    where pt.tgname =
      'daily_question_answers_notify_focused_partner_waiting'
      and not pt.tgisinternal
  ),
  'daily answers share the focused completion notification path'
);

insert into public.ai_focused_questions (
  couple_id,
  question_id,
  status
)
select
  '27000000-0000-0000-0000-000000000001',
  q.id,
  'answered_by_one'
from public.questions as q
join public.ai_question_curricula as aiqc
  on aiqc.version = q.curriculum_version
where aiqc.status = 'active'
  and q.is_active;

select is(
  (
    select count(*)::integer
    from public.ai_focused_questions as aifq
    where aifq.couple_id =
      '27000000-0000-0000-0000-000000000001'
  ),
  (
    select aiqc.question_count
    from public.ai_question_curricula as aiqc
    where aiqc.status = 'active'
    order by aiqc.version desc
    limit 1
  ),
  'the fixture contains the complete active foundation curriculum'
);

insert into public.ai_focused_question_answers (
  focused_question_id,
  user_id,
  answer_text
)
select
  aifq.id,
  '17000000-0000-0000-0000-000000000001',
  'focused answer ' || q.curriculum_position::text
from public.ai_focused_questions as aifq
join public.questions as q on q.id = aifq.question_id
join public.ai_question_curricula as aiqc
  on aiqc.version = q.curriculum_version
where aifq.couple_id = '27000000-0000-0000-0000-000000000001'
  and aiqc.status = 'active'
  and q.curriculum_position < aiqc.question_count;

select is(
  (
    select count(*)
    from public.app_notification_events as ane
    where ane.couple_id = '27000000-0000-0000-0000-000000000001'
      and ane.event_type = 'ai_focused_partner_waiting'
  ),
  0::bigint,
  'partial focused progress does not notify the partner'
);

insert into public.ai_focused_question_answers (
  focused_question_id,
  user_id,
  answer_text
)
select
  aifq.id,
  '17000000-0000-0000-0000-000000000001',
  'final focused answer'
from public.ai_focused_questions as aifq
join public.questions as q on q.id = aifq.question_id
join public.ai_question_curricula as aiqc
  on aiqc.version = q.curriculum_version
where aifq.couple_id = '27000000-0000-0000-0000-000000000001'
  and aiqc.status = 'active'
  and q.curriculum_position = aiqc.question_count;

select is(
  (
    select count(*)
    from public.app_notification_events as ane
    where ane.couple_id = '27000000-0000-0000-0000-000000000001'
      and ane.event_type = 'ai_focused_partner_waiting'
  ),
  1::bigint,
  'the final focused answer creates one partner waiting event'
);
select is(
  (
    select ane.sender_user_id
    from public.app_notification_events as ane
    where ane.couple_id = '27000000-0000-0000-0000-000000000001'
      and ane.event_type = 'ai_focused_partner_waiting'
  ),
  '17000000-0000-0000-0000-000000000001'::uuid,
  'the member who completed the foundation is the event sender'
);
select is(
  (
    select ane.receiver_user_id
    from public.app_notification_events as ane
    where ane.couple_id = '27000000-0000-0000-0000-000000000001'
      and ane.event_type = 'ai_focused_partner_waiting'
  ),
  '17000000-0000-0000-0000-000000000002'::uuid,
  'the unfinished partner is the event receiver'
);
select is(
  (
    select (ane.payload->>'completed_count')::integer
    from public.app_notification_events as ane
    where ane.couple_id = '27000000-0000-0000-0000-000000000001'
      and ane.event_type = 'ai_focused_partner_waiting'
  ),
  (
    select aiqc.question_count
    from public.ai_question_curricula as aiqc
    where aiqc.status = 'active'
    order by aiqc.version desc
    limit 1
  ),
  'the waiting event records complete foundation progress'
);

insert into public.ai_focused_question_answers (
  focused_question_id,
  user_id,
  answer_text
)
select
  aifq.id,
  '17000000-0000-0000-0000-000000000002',
  'partner answer ' || q.curriculum_position::text
from public.ai_focused_questions as aifq
join public.questions as q on q.id = aifq.question_id
where aifq.couple_id = '27000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)
    from public.app_notification_events as ane
    where ane.couple_id = '27000000-0000-0000-0000-000000000001'
      and ane.event_type = 'ai_focused_partner_waiting'
  ),
  1::bigint,
  'finishing after the partner does not create a reverse waiting event'
);

delete from public.app_notification_events as ane
where ane.couple_id = '27000000-0000-0000-0000-000000000001'
  and ane.event_type = 'ai_focused_partner_waiting';

delete from public.ai_focused_question_answers as aifqa
using public.ai_focused_questions as aifq
where aifqa.focused_question_id = aifq.id
  and aifq.couple_id = '27000000-0000-0000-0000-000000000001';

insert into public.ai_focused_question_answers (
  focused_question_id,
  user_id,
  answer_text
)
select
  aifq.id,
  '17000000-0000-0000-0000-000000000001',
  'focused answer ' || q.curriculum_position::text
from public.ai_focused_questions as aifq
join public.questions as q on q.id = aifq.question_id
join public.ai_question_curricula as aiqc
  on aiqc.version = q.curriculum_version
where aifq.couple_id = '27000000-0000-0000-0000-000000000001'
  and aiqc.status = 'active'
  and q.curriculum_position < aiqc.question_count;

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values (
  '37000000-0000-0000-0000-000000000001',
  '27000000-0000-0000-0000-000000000001',
  current_date,
  'question_generated'
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
  '47000000-0000-0000-0000-000000000001',
  '27000000-0000-0000-0000-000000000001',
  q.id,
  current_date,
  'pending',
  '37000000-0000-0000-0000-000000000001'
from public.questions as q
join public.ai_question_curricula as aiqc
  on aiqc.version = q.curriculum_version
where aiqc.status = 'active'
  and q.curriculum_position = aiqc.question_count;

insert into public.daily_question_answers (
  daily_question_id,
  user_id,
  answer_text
)
values (
  '47000000-0000-0000-0000-000000000001',
  '17000000-0000-0000-0000-000000000001',
  'final daily answer'
);

select is(
  (
    select count(*)
    from public.app_notification_events as ane
    where ane.couple_id = '27000000-0000-0000-0000-000000000001'
      and ane.event_type = 'ai_focused_partner_waiting'
  ),
  1::bigint,
  'a daily answer can complete focused progress and notify the partner'
);
select is(
  (
    select ane.receiver_user_id
    from public.app_notification_events as ane
    where ane.couple_id = '27000000-0000-0000-0000-000000000001'
      and ane.event_type = 'ai_focused_partner_waiting'
  ),
  '17000000-0000-0000-0000-000000000002'::uuid,
  'the daily completion path targets the unfinished partner'
);

update public.daily_question_answers
set answer_text = 'updated final daily answer'
where daily_question_id = '47000000-0000-0000-0000-000000000001'
  and user_id = '17000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)
    from public.app_notification_events as ane
    where ane.couple_id = '27000000-0000-0000-0000-000000000001'
      and ane.event_type = 'ai_focused_partner_waiting'
  ),
  1::bigint,
  'editing an answer does not duplicate the waiting notification'
);

select * from finish();
rollback;
