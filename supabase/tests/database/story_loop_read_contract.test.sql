begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(13);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '14000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'story-read-a@example.test',
    now(),
    now()
  ),
  (
    '14000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'story-read-b@example.test',
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
  '24000000-0000-0000-0000-000000000001',
  'STORYRD1',
  '14000000-0000-0000-0000-000000000001',
  '14000000-0000-0000-0000-000000000002',
  current_date - 30,
  'active',
  now(),
  'default'
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
  '34000000-0000-0000-0000-000000000001',
  '24000000-0000-0000-0000-000000000001',
  current_date - 1,
  'question_generated',
  now(),
  now()
);

insert into public.story_loop_cards (
  id,
  story_loop_id,
  couple_id,
  couple_date,
  author_user_id,
  preview_path,
  scene_data_path,
  has_drawing,
  submitted_at,
  revision
)
values
  (
    '44000000-0000-0000-0000-000000000001',
    '34000000-0000-0000-0000-000000000001',
    '24000000-0000-0000-0000-000000000001',
    current_date - 1,
    '14000000-0000-0000-0000-000000000001',
    '24000000-0000-0000-0000-000000000001/loops/'
      || (current_date - 1)::text
      || '/14000000-0000-0000-0000-000000000001/preview.png',
    '24000000-0000-0000-0000-000000000001/loops/'
      || (current_date - 1)::text
      || '/14000000-0000-0000-0000-000000000001/scene.json',
    true,
    now() - interval '2 minutes',
    2
  ),
  (
    '44000000-0000-0000-0000-000000000002',
    '34000000-0000-0000-0000-000000000001',
    '24000000-0000-0000-0000-000000000001',
    current_date - 1,
    '14000000-0000-0000-0000-000000000002',
    '24000000-0000-0000-0000-000000000001/loops/'
      || (current_date - 1)::text
      || '/14000000-0000-0000-0000-000000000002/preview.png',
    '24000000-0000-0000-0000-000000000001/loops/'
      || (current_date - 1)::text
      || '/14000000-0000-0000-0000-000000000002/scene.json',
    true,
    now() - interval '1 minute',
    3
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
  '54000000-0000-0000-0000-000000000001',
  '24000000-0000-0000-0000-000000000001',
  q.id,
  current_date - 1,
  'pending',
  '34000000-0000-0000-0000-000000000001'
from public.questions as q
where q.is_active
order by q.created_at, q.id
limit 1;

insert into public.daily_question_answers (
  id,
  daily_question_id,
  user_id,
  answer_text,
  answered_at
)
values
  (
    '64000000-0000-0000-0000-000000000001',
    '54000000-0000-0000-0000-000000000001',
    '14000000-0000-0000-0000-000000000001',
    '내 답변',
    now() - interval '30 seconds'
  ),
  (
    '64000000-0000-0000-0000-000000000002',
    '54000000-0000-0000-0000-000000000001',
    '14000000-0000-0000-0000-000000000002',
    '상대 답변',
    now() - interval '20 seconds'
  );

update public.daily_questions
set status = 'completed'
where id = '54000000-0000-0000-0000-000000000001';

update public.daily_story_loops
set status = 'completed'
where id = '34000000-0000-0000-0000-000000000001';

select set_config(
  'request.jwt.claim.sub',
  '14000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  (select card_count from public.get_story_loop_detail(current_date - 1)),
  2,
  'detail reports both story cards'
);
select is(
  (select first_card_id from public.get_story_loop_detail(current_date - 1)),
  '44000000-0000-0000-0000-000000000001'::uuid,
  'detail orders the earliest submitted card first'
);
select is(
  (select second_card_id from public.get_story_loop_detail(current_date - 1)),
  '44000000-0000-0000-0000-000000000002'::uuid,
  'detail orders the later submitted card second'
);
select is(
  (select loop_status from public.get_story_loop_detail(current_date - 1)),
  'completed',
  'detail preserves the completed loop state'
);
select is(
  (select daily_question_id from public.get_story_loop_detail(current_date - 1)),
  '54000000-0000-0000-0000-000000000001'::uuid,
  'detail links the loop question'
);
select is(
  (select my_answer_text from public.get_story_loop_detail(current_date - 1)),
  '내 답변',
  'detail returns the requesting member answer'
);
select is(
  (select partner_answer_text from public.get_story_loop_detail(current_date - 1)),
  '상대 답변',
  'detail reveals the partner answer after both members answer'
);
select is(
  (select answer_count from public.get_story_loop_detail(current_date - 1)),
  2,
  'detail reports both answers'
);
select is(
  (
    select card_count
    from public.get_story_loop_month_summary(
      date_trunc('month', current_date - 1)::date
    )
    where couple_date = current_date - 1
  ),
  2,
  'month summary reports the same card count'
);
select is(
  (
    select first_card_id
    from public.get_story_loop_month_summary(
      date_trunc('month', current_date - 1)::date
    )
    where couple_date = current_date - 1
  ),
  '44000000-0000-0000-0000-000000000001'::uuid,
  'month summary preserves card ordering'
);
select is(
  (select card_count from public.get_today_story_loop_summary()),
  0,
  'today summary returns an empty card state before either member posts'
);
select is(
  (select can_edit_story from public.get_today_story_loop_summary()),
  true,
  'today summary allows an active member to add a card'
);
select is(
  (select story_edit_locked from public.get_today_story_loop_summary()),
  false,
  'today summary keeps a new story unlocked'
);

select * from finish();
rollback;
