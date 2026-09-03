begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(14);

select has_column(
  'public',
  'questions',
  'fallback_position',
  'questions exposes a fixed fallback position'
);

select is(
  (
    select count(*)
    from public.questions as q
    where q.fallback_position is not null
      and q.is_active
  ),
  191::bigint,
  'the reviewed fallback pool contains exactly 191 active questions'
);

select ok(
  not exists (
    select q.fallback_position
    from public.questions as q
    where q.fallback_position is not null
    group by q.fallback_position
    having count(*) > 1
  ),
  'fallback positions are unique'
);

select is(
  (
    select min(q.fallback_position)
    from public.questions as q
    where q.fallback_position is not null
      and q.is_active
  ),
  10,
  'the fallback sequence starts at position 10'
);

select is(
  (
    select max(q.fallback_position)
    from public.questions as q
    where q.fallback_position is not null
      and q.is_active
  ),
  1910,
  'the fallback sequence leaves insertion gaps through position 1910'
);

select ok(
  not exists (
    select 1
    from public.questions as q
    where q.fallback_position is not null
      and (
        q.source <> 'curated'
        or q.question_key is null
        or q.curriculum_version is not null
      )
  ),
  'fallback questions are curated, keyed, and separate from the foundation'
);

select ok(
  not exists (
    select 1
    from public.questions as q
    where q.curriculum_version = 1
      and q.fallback_position is not null
  ),
  'foundation questions never enter the fallback sequence'
);

select ok(
  not exists (
    select 1
    from (
      select
        q.fallback_position,
        lag(q.fallback_position) over (
          order by q.fallback_position
        ) as previous_position
      from public.questions as q
      where q.fallback_position is not null
        and q.is_active
    ) as ordered_fallbacks
    where ordered_fallbacks.previous_position is not null
      and ordered_fallbacks.fallback_position
        - ordered_fallbacks.previous_position <> 10
  ),
  'fallback positions advance in stable increments of 10'
);

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
    'fallback-user-a@example.test',
    now(),
    now()
  ),
  (
    '17000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'fallback-user-b@example.test',
    now(),
    now()
  ),
  (
    '17000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'fallback-user-c@example.test',
    now(),
    now()
  ),
  (
    '17000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'fallback-user-d@example.test',
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
values
  (
    '27000000-0000-0000-0000-000000000001',
    'FBTEST01',
    '17000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000002',
    current_date - 365,
    'active',
    now(),
    'default'
  ),
  (
    '27000000-0000-0000-0000-000000000002',
    'FBTEST02',
    '17000000-0000-0000-0000-000000000003',
    '17000000-0000-0000-0000-000000000004',
    current_date - 365,
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
values
  (
    '37000000-0000-0000-0000-000000000001',
    '27000000-0000-0000-0000-000000000001',
    current_date - 6,
    'waiting_partner_card'
  ),
  (
    '37000000-0000-0000-0000-000000000002',
    '27000000-0000-0000-0000-000000000001',
    current_date - 5,
    'waiting_partner_card'
  ),
  (
    '37000000-0000-0000-0000-000000000003',
    '27000000-0000-0000-0000-000000000001',
    current_date - 3,
    'waiting_partner_card'
  ),
  (
    '37000000-0000-0000-0000-000000000004',
    '27000000-0000-0000-0000-000000000002',
    current_date,
    'waiting_partner_card'
  );

create temporary table first_fallback_assignment
on commit drop
as
select (
  private.assign_curated_fallback_question_to_story_loop(c, dsl)
).*
from public.couples as c
join public.daily_story_loops as dsl
  on dsl.couple_id = c.id
where dsl.id = '37000000-0000-0000-0000-000000000001';

select is(
  (
    select q.fallback_position
    from first_fallback_assignment as assignment
    join public.questions as q on q.id = assignment.question_id
  ),
  10,
  'a couple receives the first unexposed fallback position'
);

create temporary table second_fallback_assignment
on commit drop
as
select (
  private.assign_curated_fallback_question_to_story_loop(c, dsl)
).*
from public.couples as c
join public.daily_story_loops as dsl
  on dsl.couple_id = c.id
where dsl.id = '37000000-0000-0000-0000-000000000002';

select is(
  (
    select q.fallback_position
    from second_fallback_assignment as assignment
    join public.questions as q on q.id = assignment.question_id
  ),
  20,
  'the next assignment never repeats an already exposed fallback'
);

insert into public.questions (
  id,
  source,
  question_key,
  question_text,
  category,
  is_active
)
select
  '67000000-0000-0000-0000-000000000001',
  'ai',
  'fallback_category_guard_fixture',
  '직전 질문 분류 회피를 확인하는 테스트 질문',
  q.category,
  true
from public.questions as q
where q.fallback_position = 30;

insert into public.daily_questions (
  id,
  couple_id,
  question_id,
  assigned_date,
  status
)
values (
  '47000000-0000-0000-0000-000000000001',
  '27000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  current_date - 4,
  'pending'
);

create temporary table category_guarded_assignment
on commit drop
as
select (
  private.assign_curated_fallback_question_to_story_loop(c, dsl)
).*
from public.couples as c
join public.daily_story_loops as dsl
  on dsl.couple_id = c.id
where dsl.id = '37000000-0000-0000-0000-000000000003';

select is(
  (
    select q.fallback_position
    from category_guarded_assignment as assignment
    join public.questions as q on q.id = assignment.question_id
  ),
  40,
  'the selector skips the earliest candidate when its category repeats'
);

select is(
  (
    select count(*)
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.couple_id = '27000000-0000-0000-0000-000000000001'
      and q.fallback_position = 30
  ),
  0::bigint,
  'skipping a category does not mark that fallback as exposed'
);

insert into public.daily_questions (
  couple_id,
  question_id,
  assigned_date,
  status
)
select
  '27000000-0000-0000-0000-000000000002',
  ordered_fallback.question_id,
  current_date - ordered_fallback.sequence_number,
  'pending'
from (
  select
    q.id as question_id,
    row_number() over (order by q.fallback_position)::integer
      as sequence_number
  from public.questions as q
  where q.fallback_position is not null
    and q.is_active
) as ordered_fallback;

select is(
  (
    select (
      private.assign_curated_fallback_question_to_story_loop(c, dsl)
    ).id
    from public.couples as c
    join public.daily_story_loops as dsl
      on dsl.couple_id = c.id
    where dsl.id = '37000000-0000-0000-0000-000000000004'
  ),
  null::uuid,
  'an exhausted fallback pool returns null instead of repeating a question'
);

select is(
  (
    select count(distinct dq.question_id)
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.couple_id = '27000000-0000-0000-0000-000000000002'
      and q.fallback_position is not null
  ),
  191::bigint,
  'pool exhaustion fixture exposes every fallback exactly once'
);

select * from finish();
rollback;
