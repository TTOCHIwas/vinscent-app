begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(27);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '1a000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'decoupled-a@example.test',
    now(),
    now()
  ),
  (
    '1a000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'decoupled-b@example.test',
    now(),
    now()
  ),
  (
    '1a000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'question-a@example.test',
    now(),
    now()
  ),
  (
    '1a000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'question-b@example.test',
    now(),
    now()
  );

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
  '1a000000-0000-0000-0000-000000000001'::uuid
  and '1a000000-0000-0000-0000-000000000004'::uuid;

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  user_b_id,
  relationship_start_date,
  question_delivery_time,
  question_delivery_time_set_at,
  next_question_delivery_time,
  next_question_delivery_time_effective_date,
  timezone,
  status,
  connected_at,
  character_setup_status
)
values
  (
    '2a000000-0000-0000-0000-000000000001',
    'DECOUP1',
    '1a000000-0000-0000-0000-000000000001',
    '1a000000-0000-0000-0000-000000000002',
    current_date - 30,
    '09:00:00',
    now(),
    null,
    null,
    'UTC',
    'active',
    now(),
    'default'
  ),
  (
    '2a000000-0000-0000-0000-000000000002',
    'DECOUP2',
    '1a000000-0000-0000-0000-000000000003',
    '1a000000-0000-0000-0000-000000000004',
    current_date - 30,
    '23:59:00',
    now(),
    '09:00:00',
    current_date,
    'UTC',
    'active',
    now(),
    'default'
  );

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values (
  '3a000000-0000-0000-0000-000000000001',
  '2a000000-0000-0000-0000-000000000001',
  current_date,
  'waiting_partner_card'
);

insert into public.story_loop_cards (
  id,
  story_loop_id,
  couple_id,
  couple_date,
  author_user_id,
  artifact_revision,
  preview_path,
  scene_data_path,
  has_drawing,
  submitted_at
)
values
  (
    '4a000000-0000-0000-0000-000000000001',
    '3a000000-0000-0000-0000-000000000001',
    '2a000000-0000-0000-0000-000000000001',
    current_date,
    '1a000000-0000-0000-0000-000000000001',
    '5a000000-0000-0000-0000-000000000001',
    '2a000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/1a000000-0000-0000-0000-000000000001/'
      || '5a000000-0000-0000-0000-000000000001/preview.png',
    '2a000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/1a000000-0000-0000-0000-000000000001/'
      || '5a000000-0000-0000-0000-000000000001/scene.json',
    true,
    now() - interval '3 minutes'
  ),
  (
    '4a000000-0000-0000-0000-000000000002',
    '3a000000-0000-0000-0000-000000000001',
    '2a000000-0000-0000-0000-000000000001',
    current_date,
    '1a000000-0000-0000-0000-000000000001',
    '5a000000-0000-0000-0000-000000000002',
    '2a000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/1a000000-0000-0000-0000-000000000001/'
      || '5a000000-0000-0000-0000-000000000002/preview.png',
    '2a000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/1a000000-0000-0000-0000-000000000001/'
      || '5a000000-0000-0000-0000-000000000002/scene.json',
    true,
    now() - interval '2 minutes'
  ),
  (
    '4a000000-0000-0000-0000-000000000003',
    '3a000000-0000-0000-0000-000000000001',
    '2a000000-0000-0000-0000-000000000001',
    current_date,
    '1a000000-0000-0000-0000-000000000002',
    '5a000000-0000-0000-0000-000000000003',
    '2a000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/1a000000-0000-0000-0000-000000000002/'
      || '5a000000-0000-0000-0000-000000000003/preview.png',
    '2a000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/1a000000-0000-0000-0000-000000000002/'
      || '5a000000-0000-0000-0000-000000000003/scene.json',
    true,
    now() - interval '1 minute'
  );

select set_config(
  'request.jwt.claim.sub',
  '1a000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select throws_ok(
  $$select * from public.upsert_today_story_loop_card(
    '6a000000-0000-0000-0000-000000000001',
    'unused-preview',
    'unused-scene',
    null,
    false,
    true,
    false,
    0,
    0,
    1
  )$$,
  'P0001',
  'story_card_locked',
  'legacy edit requests cannot create a duplicate card'
);
select is(
  (select count(*) from public.get_today_story_card_stacks()),
  2::bigint,
  'home returns one stack per member'
);
select is(
  (
    select latest_card_id
    from public.get_today_story_card_stacks()
    where author_user_id = '1a000000-0000-0000-0000-000000000001'
  ),
  '4a000000-0000-0000-0000-000000000002'::uuid,
  'the newest card is the stack cover'
);
select is(
  (
    select card_count
    from public.get_today_story_card_stacks()
    where author_user_id = '1a000000-0000-0000-0000-000000000001'
  ),
  2,
  'the stack reports its complete card count'
);
select is(
  (
    select count(*)
    from public.get_story_card_stack(
      current_date,
      '1a000000-0000-0000-0000-000000000001'
    )
  ),
  2::bigint,
  'the viewer can load all cards for one member'
);
select is(
  (
    select card_id
    from public.get_story_card_stack(
      current_date,
      '1a000000-0000-0000-0000-000000000001'
    )
    order by position
    limit 1
  ),
  '4a000000-0000-0000-0000-000000000001'::uuid,
  'the stack is ordered from oldest to newest'
);
select is(
  (
    select count(*)
    from public.get_story_card_stack(
      current_date,
      '1a000000-0000-0000-0000-000000000001'
    )
    where not is_read
  ),
  0::bigint,
  'an author always reads their own cards as already seen'
);
select is(
  (
    select is_read
    from public.get_story_card_stack(
      current_date,
      '1a000000-0000-0000-0000-000000000002'
    )
    limit 1
  ),
  false,
  'a newly submitted partner card starts unread'
);
select is(
  public.acknowledge_story_card(
    '4a000000-0000-0000-0000-000000000003'
  ),
  true,
  'a viewer can acknowledge a readable partner card'
);
select is(
  (
    select is_read
    from public.get_story_card_stack(
      current_date,
      '1a000000-0000-0000-0000-000000000002'
    )
    limit 1
  ),
  true,
  'an acknowledged partner card is returned as read'
);
select lives_ok(
  $$select public.set_today_story_card_featured(
    '4a000000-0000-0000-0000-000000000001'
  )$$,
  'a member can feature one of their cards'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '1a000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;

select is(
  public.acknowledge_story_card(
    '4a000000-0000-0000-0000-000000000003'
  ),
  false,
  'a user outside the couple cannot acknowledge the card'
);

reset role;

select is(
  (
    select count(*)
    from public.story_loop_cards
    where couple_id = '2a000000-0000-0000-0000-000000000001'
      and author_user_id = '1a000000-0000-0000-0000-000000000001'
      and couple_date = current_date
      and is_featured
  ),
  1::bigint,
  'only one own card is featured for the day'
);

select set_config(
  'request.jwt.claim.sub',
  '1a000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select throws_ok(
  $$select public.delete_story_card(
    '4a000000-0000-0000-0000-000000000003'
  )$$,
  'P0001',
  'story_card_not_owned',
  'a partner card cannot be deleted'
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
    where couple_id = '2a000000-0000-0000-0000-000000000002'
  ),
  2::bigint,
  'a due question creates one delivery for each member without cards'
);

select is(
  (
    select count(*)
    from public.assign_due_daily_questions(
      date_trunc('day', now()) + interval '10 hours',
      100
    )
    where couple_id = '2a000000-0000-0000-0000-000000000002'
  ),
  2::bigint,
  'an assigned question is returned again until delivery dispatch is claimed'
);

reset role;

insert into public.push_notification_dispatches (
  notification_type,
  source_id,
  receiver_user_id
)
select
  'daily_question_delivery',
  question.id,
  member.user_id
from public.daily_questions as question
cross join (
  values ('1a000000-0000-0000-0000-000000000003'::uuid)
) as member(user_id)
where question.couple_id = '2a000000-0000-0000-0000-000000000002'
  and question.assigned_date = current_date;

set local role service_role;

select is(
  (
    select count(*)
    from public.assign_due_daily_questions(
      date_trunc('day', now()) + interval '10 hours',
      100
    )
    where couple_id = '2a000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'only the member without a dispatch claim remains in the delivery queue'
);

reset role;

insert into public.push_notification_dispatches (
  notification_type,
  source_id,
  receiver_user_id
)
select
  'daily_question_delivery',
  question.id,
  '1a000000-0000-0000-0000-000000000004'::uuid
from public.daily_questions as question
where question.couple_id = '2a000000-0000-0000-0000-000000000002'
  and question.assigned_date = current_date;

set local role service_role;

select is(
  (
    select count(*)
    from public.assign_due_daily_questions(
      date_trunc('day', now()) + interval '10 hours',
      100
    )
    where couple_id = '2a000000-0000-0000-0000-000000000002'
  ),
  0::bigint,
  'a question leaves the delivery queue after both dispatches are claimed'
);

reset role;

select is(
  (
    select question_delivery_time
    from public.couples
    where id = '2a000000-0000-0000-0000-000000000002'
  ),
  '09:00:00'::time,
  'a pending earlier delivery time is applied before due couples are selected'
);
select is(
  (
    select next_question_delivery_time
    from public.couples
    where id = '2a000000-0000-0000-0000-000000000002'
  ),
  null::time,
  'the applied delivery time clears its pending value'
);

select is(
  (
    select count(*)
    from public.daily_questions
    where couple_id = '2a000000-0000-0000-0000-000000000002'
      and assigned_date = current_date
  ),
  1::bigint,
  'question assignment is independent from card creation'
);
select is(
  (
    select story_loop_id
    from public.daily_questions
    where couple_id = '2a000000-0000-0000-0000-000000000002'
      and assigned_date = current_date
  ),
  null::uuid,
  'a new daily question has no lasting story loop dependency'
);
select is(
  (
    select count(*)
    from public.story_loop_cards
    where couple_id = '2a000000-0000-0000-0000-000000000002'
  ),
  0::bigint,
  'the independently assigned question does not create a card'
);
select is(
  (
    select count(*)
    from public.daily_story_loops
    where couple_id = '2a000000-0000-0000-0000-000000000002'
      and couple_date = current_date
  ),
  0::bigint,
  'the independently assigned question leaves no temporary story loop'
);

select set_config(
  'request.jwt.claim.sub',
  '1a000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;

select lives_ok(
  $$select * from public.submit_daily_question_answer(
    (
      select daily_question_id
      from public.get_daily_question_detail(null)
    ),
    '내 답변'
  )$$,
  'the direct daily question accepts an answer'
);
select is(
  (select status from public.get_today_question_answer_state()),
  'answered_by_one',
  'the direct answer state is readable without a story loop'
);
select is(
  (select count(*) from public.get_or_assign_today_question()),
  1::bigint,
  'the today question read RPC returns the scheduled question'
);

select * from finish();
rollback;
